module namespace report = 'report';
declare default function namespace 'report';

(:
TODO
* README
* schema changes:
  * change `hit` to `item`
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

declare variable $report:ERROR  := xs:QName("XQREPORT");
declare variable $report:SCHEMA := file:base-dir() || '../../etc/report.xsd';


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
  let $reported-items := $testF($items, $cache) ! element item {
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
      element old       { .('old') },
      element new       { .('new') }[$recommend],
      element info      { .('info') }[$info]
    )
  }
  
  let $report := element report {
    attribute count { fn:count($reported-items) },
    attribute time { $timestamp },
    attribute id { new-id() },
    attribute no-id-selector { $noIdSelector },
    attribute test-id { $testId },
    $reported-items
  }
  
  return $report
};

declare %updating function apply($report as element(report), $rootContext as node(),
  $options as map(*))
{
  let $ok := check-options($options) and validate($report)
  
  let $noIdSelector := xs:boolean($report/@no-id-selector) eq fn:true()
  let $reported-items := $report/item
  for $item in $options('items-selector')($rootContext)
  let $itemId :=
    if($noIdSelector) then
      xpath-location($item)
    else
      $options('id-selector')($item)
  let $reported-item := $reported-items[@item-id eq $itemId]
  where $reported-item
  (: there might be several items on the descendant axis of an identical item :)
  return $reported-item ! apply-recommendation(., $item)
};

declare function apply-to-copy($report as element(report), $rootContext as node(),
  $options as map(*)) as node()
{
  $rootContext update (apply($report, ., $options))
};




(: ********************** utilities *********************:)

declare %private %updating function apply-recommendation(
  $reported-item as element(item),
  $item as node())
{
  let $new := $reported-item/new
  where $new
  let $new  := $new/child::node()
  let $old := $reported-item/old/child::node()
  let $target := evaluate-xpath($item, $reported-item/@xpath)
  return
    (: safety measure - throw error in case original already changed :)
    if(fn:not(fn:deep-equal($old, $target))) then
      db:output(error("Report recommendation is outdated: " || $reported-item))
    else
      (: if $new empty -> delete, else -> replace with $new sequence :)
      replace node $target with $new
};

declare function validate($report as element(report)) as xs:boolean
{
  let $v := fn:string-join(validate:xsd-info($report, fn:doc($report:SCHEMA)), "&#xA;")
  return if($v) then error($v) else fn:true()
};

declare function check-options($options as map(*)) as xs:boolean
{
  (: TODO implement / check typing? :)
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
