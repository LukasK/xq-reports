(:~
 : Report module.
 : @author Lukas Kircher, BaseX GmbH, 2012-15
 :)
module namespace report = 'report';
declare default function namespace 'report';

(:
TODO
* README - examples, options
* unit tests
  * <old><foo/></old><new>text</new>?
  * report schema
  * cache use
  * expected fails
  * replacing / deleting the root
  * replacing with sequence of text nodes
  * namespaces
* code TODOs
* add version number + license
* naming ok?
* documentation
* think about better integration: voktool + general
* snake case variables etc.
:)

declare variable $report:ERROR  := xs:QName("XQREPORT");
declare variable $report:SCHEMA := file:base-dir() || '../../etc/report.xsd';

(: option keys :)
declare variable $report:ITEMS      := 'items-selector';
declare variable $report:ITEMID     := 'id-selector';
declare variable $report:TEST       := 'test';
declare variable $report:TESTID     := 'test-id';
declare variable $report:CACHE      := 'cache';
(: test result keys :)
declare variable $report:ITEM       := 'item';
declare variable $report:OLD        := 'old';
declare variable $report:NEW        := 'new';
declare variable $report:INFO       := 'info';


declare function as-xml($root-context as node(), $options as map(*))
{
  let $ok := check-options($options, fn:false())
  let $timestamp := fn:current-dateTime()
  
  (: OPTIONS :)
  let $id-selector-f := $options($report:ITEMID)
  let $no-id-selector := fn:empty($id-selector-f)
  let $items := $options($report:ITEMS)($root-context)
  let $cache := $options($report:CACHE)
  let $test-id := $options($report:TESTID)
  let $test-f := $options($report:TEST)
  
  let $items := if($no-id-selector) then $items else $items ! (. update ())
  let $reported-items := $test-f($items, $cache) ! element item {
    let $new-key := map:keys(.) = $report:NEW
    let $item := .($report:ITEM)
    let $old  := .($report:OLD)
    let $new  := .($report:NEW)
    let $info := .($report:INFO)
    return (
      attribute item-id {
        if($no-id-selector) then
          xpath-location($item)
        else
          $id-selector-f($item)
      },
      attribute xpath   {
        let $old-loc := xpath-location($old)
        return if($no-id-selector) then
          fn:replace($old-loc, escape-location-path-pattern(xpath-location($item)), '')
        else
          $old-loc
      },
      element old       { $old },
      element new       { $new }[$new-key],
      element info      { $info }[fn:exists($info)]
    )
  }
  
  let $report := element report {
    attribute count { fn:count($reported-items) },
    attribute time { $timestamp },
    attribute id { new-id() },
    attribute no-id-selector { $no-id-selector },
    attribute test-id { $test-id },
    $reported-items
  }
  
  return $report
};

declare %updating function apply($report as element(report), $root-context as node(),
  $options as map(*))
{
  let $ok := check-options($options, fn:true()) and validate($report)
  let $no-id-selector := xs:boolean($report/@no-id-selector) eq fn:true()
  let $reported-items := $report/item
  for $item in $options($report:ITEMS)($root-context)
  let $item-id :=
    if($no-id-selector) then
      xpath-location($item)
    else
      $options($report:ITEMID)($item)
  let $reported-item := $reported-items[@item-id eq $item-id]
  where $reported-item
  (: there might be several items on the descendant axis of an identical item :)
  return $reported-item ! apply-recommendation(., $item)
};

declare function apply-to-copy($report as element(report), $root-context as node(),
  $options as map(*)) as node()
{
  $root-context update (apply($report, ., $options))
};




(: ********************************** private functions ***************************************** :)
declare %private %updating function apply-recommendation(
  $reported-item as element(item),
  $item as node())
{
  let $new := $reported-item/new
  where $new
  let $new  := $new/child::node()
  let $old := $reported-item/old/child::node()
  let $target := xquery:eval("." || $reported-item/@xpath, map { '': $item })
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

declare function check-options($o as map(*), $apply-report as xs:boolean) as xs:boolean
{
  let $e := function($k) {
    error('Type of option invalid: ' || $k)
  }
  return if(fn:not($o($report:ITEMS)   instance of function(node()) as node()*)) then  $e('ITEM')
    else if(fn:not($o($report:ITEMID)  instance of (function(node()) as xs:string)?))
      then $e('ITEMID')
    else if(fn:not($o($report:TESTID)  instance of xs:string?)) then $e('TESTID')
    else if(fn:not($o($report:CACHE)   instance of map(*)?)) then $e('CACHE')
    else if(fn:not($o($report:TEST)    instance of function(node()*, map(*)?) as map(*)*)
      and fn:not($apply-report)) then $e('TEST')
    else fn:true()
};

declare function error($msg as xs:string)
{
  fn:error($report:ERROR, $msg)
};

(:~
 : Generates a random id consisting of digits [0-9] and letters [A-Z][a-z].
 :
 : @return random id string
 :)
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
  fn:replace(fn:path($n), 'Q\{.*?\}root\(\)', '')
};

declare %private function escape-location-path-pattern($s as xs:string) as xs:string
{
  $s
    ! fn:replace(., '\[', '\\[')
    ! fn:replace(., '\]', '\\]')
    ! fn:replace(., '\(', '\\(')
    ! fn:replace(., '\)', '\\)')
    ! fn:replace(., '\{', '\\{')
    ! fn:replace(., '\}', '\\}')
};
