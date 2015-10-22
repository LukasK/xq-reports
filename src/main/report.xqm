(:~
 : Report module.
 : @author Lukas Kircher, BaseX GmbH, 2012-15
 :)
module namespace report = 'report';
declare default function namespace 'report';

(:
TODO
* README - examples, options
* remove RECOMMEND parameter - check with `map:keys($map) eq 'new'` instead
* check test function return types
* make parameters optional:
  * CACHE
  * ID-SELECTOR
* unit tests
  * no recommend / recommend=true/false / missing <new/> and recommend=true
  * report schema
  * cache
  * expected fails
* code TODOs
:)

declare variable $report:ERROR  := xs:QName("XQREPORT");
declare variable $report:SCHEMA := file:base-dir() || '../../etc/report.xsd';

(: option keys :)
declare variable $report:ITEMS      := 'items-selector';
declare variable $report:ITEMID     := 'id-selector';
declare variable $report:TEST       := 'test';
declare variable $report:TESTID     := 'test-id';
declare variable $report:RECOMMEND  := 'recommend';
declare variable $report:CACHE      := 'cache';
(: test result keys :)
declare variable $report:ITEM       := 'item';
declare variable $report:OLD        := 'old';
declare variable $report:NEW        := 'new';
declare variable $report:INFO       := 'info';


declare function as-xml($rootContext as node(), $options as map(*))
{
  let $ok := check-options($options, fn:false())
  let $timestamp := timestamp()
  
  (: OPTIONS :)
  let $recommend    := $options($report:RECOMMEND) and fn:exists($options($report:RECOMMEND))
  let $idSelectorF  := $options($report:ITEMID)
  let $noIdSelector := fn:empty($idSelectorF)
  let $items        := $options($report:ITEMS)($rootContext)
  let $cache        := $options($report:CACHE)
  let $testId       := $options($report:TESTID)
  let $testF        := $options($report:TEST)
  
  let $items := if($noIdSelector) then $items else $items ! (. update ())
  let $reported-items := $testF($items, $cache) ! element item {
    let $item := .($report:ITEM)
    let $old  := .($report:OLD)
    let $new  := .($report:NEW)
    let $info := .($report:INFO)
    return (
      attribute item-id {
        if($noIdSelector) then
          xpath-location($item)
        else
          $idSelectorF($item)
      },
      attribute xpath   {
        let $oldLoc := xpath-location($old)
        return if($noIdSelector) then
          fn:replace($oldLoc, escape-location-path-pattern(xpath-location($item)), '')
        else
          $oldLoc
      },
      element old       { $old },
      element new       { $new }[$recommend],
      element info      { $info }[fn:exists($info)]
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
  let $ok := check-options($options, fn:true()) and validate($report)
  let $noIdSelector := xs:boolean($report/@no-id-selector) eq fn:true()
  let $reported-items := $report/item
  for $item in $options($report:ITEMS)($rootContext)
  let $itemId :=
    if($noIdSelector) then
      xpath-location($item)
    else
      $options($report:ITEMID)($item)
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

declare function check-options($o as map(*), $applyReport as xs:boolean) as xs:boolean
{
  let $e := function($k) {
    error('type of option invalid: ' || $k)
  }
  return if(fn:not($o($report:ITEMS)                               instance of function(node()) as node()*)) then  $e('ITEM')
    else if(fn:not($o($report:ITEMID)                              instance of (function(node()) as xs:string)?)) then $e('ITEMID')
    else if(fn:not($applyReport) and fn:not($o($report:TEST)       instance of function(node()*, map(*)) as map(*)*)) then $e('TEST')
    else if(fn:not($applyReport) and fn:not($o($report:TESTID)     instance of xs:string)) then $e('TESTID')
    else if(fn:not($applyReport) and fn:not($o($report:RECOMMEND)  instance of xs:boolean)) then $e('RECOMMEND')
    else if(fn:not($applyReport) and fn:not($o($report:CACHE)      instance of map(*)?)) then $e('CACHE')
    else fn:true()
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
