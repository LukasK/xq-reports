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
* @id: could be an id or an xpath expression (@resxq-id, @resxq-id-xpath) that leads to item/node
* schema validation support
* Unit Tests
  * replace old node with empty/sequence
  * text node as selected item -- does it work?
    * or select ctxRoot as item and return all texts in TEST function?
* apply report: check if ids in context unique (or during report creation?)
* fill info element in <hit>
* test cache
:)


(: ****************************** API ********************************** :)
declare function report:as-xml($rootContext as node(), $options as map(*))
{
  let $timestamp := report:timestamp()
  let $test := $options('test')
  let $test-id := $test('id')
  let $testF := $test('do')
  let $cache := $options('cache')
  
  let $items := $options('items-selector')($rootContext) ! (. update ())
  let $hits := $testF($items, $cache) ! element hit {
      attribute id      { $options('id-selector')(.('item')) },
      attribute xpath   { replace(fn:path(.('old')), 'root\(\)|Q\{.*?\}', '') },
      attribute test-id { .('id') },
      attribute type    { 'warning' },
      element old       { .('old') },
      element new       { .('new') },
      element info      { .('info') }
    }
  
  let $report := element report {
    attribute count { fn:count($hits) },
    attribute time { $timestamp },
    attribute id { report:new-id() },
    $hits
  }
  
  return $report
};

declare function report:apply-to-document($report as element(report), $rootContext as node(),
  $options as map(*)) as node()
{
  $rootContext update (
    let $items := $options('items-selector')(.)
    for $hit in $report/hit
    let $item := $items[$options('id-selector')(.) eq $hit/@id]
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

declare function report:check-hit(
  $hit    as element(hit),
  $strict as xs:boolean)
  as xs:boolean
{
(: TODO implement :)
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
