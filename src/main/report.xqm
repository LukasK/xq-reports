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
* new report attributes
  * input doc/db name
* @id: could be an id or an xpath expression (@resxq-id, @resxq-id-xpath) that leads to item/node
* schema validation support
:)

declare variable $report:CUSTOM-SETUP := map {
  'items': function($rootContext as item()) as element(entry)* {
    $rootContext//entry
  },
  'id': function($item as element()) {
    $item/@myId/fn:string()
  },
  'test1': function($entry as element()) {
    let $t := $entry/text()
    where fn:normalize-space($t) ne $t
    return $t
  }
};



(: ****************************** API ********************************** :)
declare function report:as-xml($rootContext as node())
{
  let $timestamp := report:timestamp()
  let $items := $report:CUSTOM-SETUP('items')($rootContext) ! (. update ())
  
  let $hits :=
    for $item in $items
    let $hit := $report:CUSTOM-SETUP('test1')($item)
    where $hit
    return $hit ! element hit {
      attribute id      { $report:CUSTOM-SETUP('id')($item) },
      attribute xpath   { replace(fn:path($hit), 'root\(\)|Q\{.*?\}', '') },
      attribute test-id { 'test1' },
      attribute type    { 'warning' },
      element old       { $hit },
      element new       { fn:normalize-space($hit) },
      element info      {  }
    }
  
  let $report := element report {
    attribute count { fn:count($hits) },
    attribute time { $timestamp },
    attribute id { report:new-id() },
    $hits
  }
  
  return $report
};

declare function report:apply-to-document($report as element(report), $rootContext as node())
{
  $rootContext update (
    let $items := $report:CUSTOM-SETUP('items')(.)
    for $hit in $report/hit
    let $item := $items[$report:CUSTOM-SETUP('id')(.) eq $hit/@id]
    return report:apply-hit-recommendation($hit, $item)
  )
};

declare %updating function report:apply-to-database($report as element(report), $rootContext as node())
{
  ()
};
(: ****************************** API ********************************** :)



(: ********************** utilities *********************:)
declare %updating function report:apply-hit-recommendation(
  $hit as element(hit),
  $item as element())
{
  report:check-hit($hit, true()) ! (
    let $cleaned  := $hit/new/child::node()
    (: do not replace with empty sequence! (for now..) :)
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

declare function report:check-hit(
  $hit    as element(hit),
  $strict as xs:boolean)
  as xs:boolean
{
  true()
};

declare function report:evaluate-xpath(
  $n    as element(),
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

declare function report:timestamp() as xs:dateTime {
  fn:adjust-dateTime-to-timezone(fn:current-dateTime(), xs:dayTimeDuration('PT0H'))
};

declare function report:new-id() as xs:string
{
  random:uuid()
    ! replace(., '-', '')
    ! xs:hexBinary(.)
    ! xs:base64Binary(.)
    ! xs:string(.)
    ! replace(., '=+$', '')
    ! fn:replace(., "[^A-Za-z0-9]", "_")
};
