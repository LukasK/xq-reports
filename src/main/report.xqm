module namespace report = 'report';
declare default function namespace 'report';

(:
<report count="2" time="2015-01-27T14:34:36.664Z" id="fSaZRLanR3223NUsz26DKw" no-id-selector="false">
  <hit id="id1" xpath="/text()[1]" test-id="test-id-normalize-ws" type="warning">
    <old>text1.1  </old>
    <new/>
    <info/>
  </hit>
  <hit id="id1" xpath="/text()[2]" test-id="test-id-normalize-ws" type="warning">
    <old> text1.2 </old>
    <new/>
    <info/>
  </hit>
</report>

TODO
* README
* schema .xsd for report (drop check-hit for a schema check of the report)
* check valid options
* make optional parameters:
  * CACHE
  * ID-SELECTOR
  * RECOMMEND
* unit tests
  * no recommend / recommend=true/false / missing <new/>
  * report schema
  * cache
  * expected fails
* code TODOs
:)

declare variable $report:ERROR := xs:QName("ERROR");


declare function as-xml($rootContext as node(), $options as map(*))
{
  let $ok := check-options($options)
  let $timestamp := timestamp()
  let $test := $options('test')
  let $testId := $test('id')
  (: operate w/o ids --> items are identified via location steps :)
  let $noIdSelector := fn:empty($options('id-selector'))
  let $testF := $test('do')
  let $recommend := $options('recommend') and fn:not(fn:empty($options('recommend')))
  let $cache := $options('cache')
  
  let $items := $options('items-selector')($rootContext)
  let $items := if($noIdSelector) then $items else $items ! (. update ())
  let $hits := $testF($items, $cache) ! element hit {
    let $info := .('info')
    return (
      attribute item-id {
        let $item := .('item')
        return if($noIdSelector) then
          xpath-location($item)
        else
          $options('id-selector')($item)
      },
      attribute xpath   {
        let $oldLoc := xpath-location(.('old'))
        return if($noIdSelector) then
          fn:replace($oldLoc, escape-location-path-pattern(xpath-location(.('item'))), '')
        else
          $oldLoc
      },
      attribute test-id { $testId },
      element old       { .('old') },
      element new       { .('new') }[$recommend],
      element info      { .('info') }[$info]
    )
  }
  
  let $report := element report {
    attribute count { fn:count($hits) },
    attribute time { $timestamp },
    attribute id { new-id() },
    attribute no-id-selector { $noIdSelector },
    $hits
  }
  
  return $report
};

declare %updating function apply($report as element(report), $rootContext as node(),
  $options as map(*))
{
  let $ok := check-options($options)
  let $noIdSelector := xs:boolean($report/@no-id-selector) eq fn:true()
  let $hits := $report/hit
  for $item in $options('items-selector')($rootContext)
  let $itemId :=
    if($noIdSelector) then
      xpath-location($item)
    else
      $options('id-selector')($item)
  let $hit := $hits[@item-id eq $itemId]
  where $hit
  (: there might be several hits on the descendant axis of an identical item :)
  return $hit ! apply-hit-recommendation(., $item)
};

declare function apply-to-copy($report as element(report), $rootContext as node(),
  $options as map(*)) as node()
{
  $rootContext update (apply($report, ., $options))
};




(: ********************** utilities *********************:)

declare %private %updating function apply-hit-recommendation(
  $hit as element(hit),
  $item as node())
{
  check-hit($hit) ! (
    let $new := $hit/new
    where $new
    let $new  := $new/child::node()
    let $old := $hit/old/child::node()
    let $target := evaluate-xpath($item, $hit/@xpath)
    return
      (: safety measure - throw error in case original already changed :)
      if(fn:not(fn:deep-equal($old, $target))) then
        db:output(error("Report recommendation is outdated: " || $hit))
      else
        (: if $new empty -> delete, else -> replace with $new sequence :)
        replace node $target with $new
  )
};

declare %private function check-hit($hit as element(hit))
  as xs:boolean
{
  if((fn:string-length($hit/@item-id), fn:string-length($hit/@test-id)) = 0 or fn:empty($hit/@xpath)) then
    error("Report hit not complete: " || $hit/@id || " " || $hit/@test-id)
  
  else if(fn:not($hit/old)) then
    error("Invalid report structure: " || "missing old element - " || $hit/* ! fn:name(.))
  
  else if(fn:count($hit/old/child::node()) ne 1) then
    error("Invalid report structure: " || "node old must contain exactely one child - " || $hit/old/child::node() ! fn:name(.))
  
  else
    fn:true()
};

declare function check-options($options as map(*)) as xs:boolean
{
  (: TODO implement :)
  fn:true()
};

declare function error($msg as xs:string)
{
  fn:error($report:ERROR, $msg)
};

declare %private function evaluate-xpath(
  $n    as node(),
  $path as xs:string
) as node()
{
  if(fn:string-length($path) eq 0) then
    $n
  else if(fn:not(fn:matches($path, "^/"))) then
    error("Path must start with a slash: " || $path)
  else
    steps($n, fn:tail(fn:tokenize($path, "/")))
};

declare %private function steps(
  $n     as element(),
  $steps as xs:string*
) as node()
{
  (: next child step :)
  let $ch  := fn:head($steps)
  (: get positional predicate :)
  let $a   := fn:analyze-string($ch, "\[\d+\]")
  let $pos := fn:replace($a/fn:match, "\[|\]", "")
  (: child position :)
  let $pos := fn:number(if(fn:string-length($pos) eq 0) then 1 else $pos)
  (: child element name :)
  let $ch  := $a/fn:non-match/fn:string()
  (: descendant steps :)
  let $dc  := fn:tail($steps)
  (: evaluate child with given name and position :)
  let $ch  :=
    if($ch eq 'text()') then
      $n/text()[$pos]
    else
      $n/*[fn:name(.) eq $ch][$pos]
  return
    if(fn:empty($dc) or $ch instance of text()) then $ch else steps($ch, $dc)
};

declare %private function timestamp() as xs:dateTime {
  fn:adjust-dateTime-to-timezone(fn:current-dateTime(), xs:dayTimeDuration('PT0H'))
};

declare %private function new-id() as xs:string
{
  random:uuid()
    ! fn:replace(., '-', '')
    ! xs:hexBinary(.)
    ! xs:base64Binary(.)
    ! xs:string(.)
    ! fn:replace(., '=+$', '')
    ! fn:replace(., "[^A-Za-z0-9]", "_")
};

declare %private function xpath-location($n as node()) as xs:string
{
  fn:replace(fn:path($n), 'root\(\)|Q\{.*?\}', '')
};

declare %private function escape-location-path-pattern($s as xs:string) as xs:string
{
  $s
    ! fn:replace(., '\[', '\\[')
    ! fn:replace(., '\]', '\\]')
    ! fn:replace(., '\(', '\\(')
    ! fn:replace(., '\)', '\\)')
};
