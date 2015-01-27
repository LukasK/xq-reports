module namespace report = 'report';

(:
<report count="1" time="2015-01-22T12:18:57.098Z" id="TJikGdmrT3Gi1xOooXqJMw">
  <hit dbid="000001" matid="MatId_787b08d312m_d703e284" xpath="/LO[1]/LOSchlagW[1]/AWLText[1]" test-id="EN-002" type="warning">
    <old>
      <itemToFix>bla</itemToFix>
    </old>
    <new>
      <itemToFix>blubb</itemToFix>
    </new>
    <info/>
  </hit>
</report>


TODO
* persistent changes
* checks/error handling
* replace old node with empty/sequence
* nested ITEMS
* apply report: check if ids in context unique (or during report creation?)
* test cache

PREREQUISITES
* 'ids' must be unique
* preserve whitespaces?
:)


(: ****************************** API ********************************** :)
declare function report:as-xml($rootContext as node(), $options as map(*))
{
  let $timestamp := report:timestamp()
  let $test := $options('test')
  let $testId := $test('id')
  (: operate w/o ids --> items are identified via location steps :)
  let $noIdSelector := fn:empty($options('id-selector'))
  let $testF := $test('do')
  let $cache := $options('cache')
  
  let $items := $options('items-selector')($rootContext)
  let $items := if($noIdSelector) then $items else $items ! (. update ())
  let $hits := $testF($items, $cache) ! element hit {
      attribute id {
        let $item := .('item')
        return if($noIdSelector) then
          report:xpath-location($item)
        else
          $options('id-selector')($item)
      },
      attribute xpath   {
        let $oldLoc := report:xpath-location(.('old'))
        return if($noIdSelector) then
          fn:replace($oldLoc, report:escape-pattern(report:xpath-location(.('item'))), '')
        else
          $oldLoc
      },
      attribute test-id { $testId },
      attribute type    { .('type') },
      element old       { .('old') },
      element new       { .('new') },
      element info      { .('info') }
    }
  
  let $report := element report {
    attribute count { fn:count($hits) },
    attribute time { $timestamp },
    attribute id { report:new-id() },
    attribute no-id-selector { $noIdSelector },
    $hits
  }
  
  return $report
};

declare %updating function report:apply($report as element(report),
  $rootContext as node(), $options as map(*))
{
  let $noIdSelector := xs:boolean($report/@no-id-selector) eq fn:true()
  let $hits := $report/hit
  for $item in $options('items-selector')($rootContext)
  let $itemId :=
    if($noIdSelector) then
      report:xpath-location($item)
    else
      $options('id-selector')($item)
  let $hit := $hits[@id eq $itemId]
  where $hit
  (: there might be several hits on the descendant axis of an identical item :)
  return $hit ! report:apply-hit-recommendation(., $item)
};

declare function report:apply-to-copy($report as element(report), $rootContext as node(),
  $options as map(*)) as node()
{
  $rootContext update (report:apply($report, ., $options))
};
(: ****************************** API ********************************** :)



(: ********************** utilities *********************:)
declare %private %updating function report:apply-hit-recommendation(
  $hit as element(hit),
  $item as node())
{
  report:check-hit($hit, true()) ! (
    let $cleaned  := $hit/new/child::node()
    (: TODO do not replace with empty sequence! (for now..) :)
    where $cleaned
    let $original := $hit/old/child::node()
    let $target   := report:evaluate-xpath($item, $hit/@xpath)
    return
      (: safety measure - throw error in case original already changed :)
      if(not(fn:deep-equal($original, $target))) then
        fn:error((), "Report recommendation is outdated: " || $hit, $hit)
      else
        replace node $target with $cleaned
  )
};

declare %private function report:check-hit(
  $hit    as element(hit),
  $strict as xs:boolean)
  as xs:boolean
{
(: TODO implement :)
  true()
};

declare %private function report:evaluate-xpath(
  $n    as node(),
  $path as xs:string
) as node()
{
  if(fn:string-length($path) eq 0) then
    $n
  else if(not(fn:matches($path, "^/"))) then
    error((), "Path must start with a slash: " || $path)
  else
    report:steps($n, tail(fn:tokenize($path, "/")))
};

declare %private function report:steps(
  $n     as element(),
  $steps as xs:string*
) as node()
{
  (: next child step :)
  let $ch  := head($steps)
  (: get positional predicate :)
  let $a   := fn:analyze-string($ch, "\[\d+\]")
  let $pos := fn:replace($a/fn:match, "\[|\]", "")
  (: child position :)
  let $pos := number(if(fn:string-length($pos) eq 0) then 1 else $pos)
  (: child element name :)
  let $ch  := $a/fn:non-match/string()
  (: descendant steps :)
  let $dc  := tail($steps)
  (: evaluate child with given name and position :)
  let $ch  :=
    if($ch eq 'text()') then
      $n/text()[$pos]
    else
      $n/*[fn:name(.) eq $ch][$pos]
  return
    if(empty($dc) or $ch instance of text()) then $ch else report:steps($ch, $dc)
};

declare %private function report:timestamp() as xs:dateTime {
  fn:adjust-dateTime-to-timezone(fn:current-dateTime(), xs:dayTimeDuration('PT0H'))
};

declare %private function report:new-id() as xs:string
{
  random:uuid()
    ! replace(., '-', '')
    ! xs:hexBinary(.)
    ! xs:base64Binary(.)
    ! xs:string(.)
    ! replace(., '=+$', '')
    ! fn:replace(., "[^A-Za-z0-9]", "_")
};

declare %private function report:xpath-location($n as node()) as xs:string
{
  replace(fn:path($n), 'root\(\)|Q\{.*?\}', '')
};

declare %private function report:escape-pattern($s as xs:string) as xs:string
{
  $s
    ! replace(., '\[', '\\[')
    ! replace(., '\]', '\\]')
    ! replace(., '\(', '\\(')
    ! replace(., '\)', '\\)')
};
