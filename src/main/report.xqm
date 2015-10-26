(:~
 : Report module.
 :
 : @author Lukas Kircher, BaseX GmbH, 2015
 : @version 0.1
 : @license BSD 2-Clause License
 :)
module namespace report = 'report';
declare default function namespace 'report';

(:
TODO
* TEST func: rename $items to $ctx
* move @xpath to 'old' element
* check empty: xpath, item-id, ... validation?
* README - examples, options
* unit tests
  * expected fails
  * replacing / deleting the root
* documentation
:)

declare variable $report:ERROR  := xs:QName("err:XQREPORT");
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

(:~
 : Creates an XML report.
 :
 : @param  $root-context Report context
 : @param  $options Options map
 : @return XML report
 :)
declare function as-xml(
  $root-context as node(),
  $options as map(*)
) as element(report) {
  let $ok := check-options($options, fn:false())
  let $timestamp := fn:current-dateTime()
  
  (: options :)
  let $id-selector-f := $options($report:ITEMID)
  let $no-id-selector := fn:empty($id-selector-f)
  let $items := $options($report:ITEMS)($root-context)
  let $err := if(fn:count($items) eq 1 and $items is $root-context)
    then error('The context root cannot be the direct target of a report') else ()
  let $cache := $options($report:CACHE)
  let $test-id := $options($report:TESTID)
  let $test-f := $options($report:TEST)
  
  let $reported-items := $test-f($items, $cache) ! element item {
    (: only make a recommendation if test function returned a NEW key/value pair :)
    let $new-key := map:keys(.) = $report:NEW
    let $item := .($report:ITEM)
    let $old  := .($report:OLD)
    let $new  := .($report:NEW)
    let $info := .($report:INFO)
    let $item-location := xpath-location($item)
    return (
      attribute item-id {
        if($no-id-selector) then
          $item-location
        else
          $id-selector-f($item)
      },
      (: determine path of 'old' node relative to item :)
      attribute xpath {
        fn:replace(xpath-location($old), escape-location-path-pattern($item-location), '')
      },
      element old { $old },
      element new { $new }[$new-key],
      element info { $info }[fn:exists($info)]
    )
  }
  return element report {
    attribute count { fn:count($reported-items) },
    attribute time { $timestamp },
    attribute id { new-id() },
    attribute no-id-selector { $no-id-selector },
    attribute test-id { $test-id },
    $reported-items
  }
};

(:~
 : Applies a report to the given context.
 :
 : @param  $report XML report to be applied
 : @param  $root-context Report context
 : @param  $options Options map
 :)
declare %updating function apply(
  $report as element(report),
  $root-context as node(),
  $options as map(*)
) {
  let $ok := check-options($options, fn:true()) and validate($report)
  let $no-id-selector := xs:boolean($report/@no-id-selector)
  let $reported-items := $report/item
  let $item-id-f := $options($report:ITEMID)
  (: loop through possible items in root context :)
  for $item in $options($report:ITEMS)($root-context)
  let $item-id := if($no-id-selector) then xpath-location($item) else $item-id-f($item)
  let $reported-item := $reported-items[@item-id eq $item-id]
  where $reported-item
  (: there might be several items on the descendant axis of an identical item :)
  return $reported-item ! apply-recommendation(., $item)
};

(:~
 : Applies a report to a copy of the given context.
 :
 : @param  $report XML report to be applied
 : @param  $root-context Report context
 : @param  $options Options map
 : @return Updated context copy
 :)
declare function apply-to-copy(
  $report as element(report),
  $root-context as node(),
  $options as map(*)
) as node() {
  $root-context update (apply($report, ., $options))
};

(: ********************************** private functions ***************************************** :)
(:~
 : Applies a recommendation, if the given item carries a <new> element.
 :
 : @param  $reported-item Report entry item
 : @param  $item Item to be changed
 :)
declare %private %updating function apply-recommendation(
  $reported-item as element(item),
  $item as node()
) {
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

(:~
 : Valdiates a report element.
 :
 : @param  $report XML report
 : @return True, if report ok.
 :)
declare function validate(
  $report as element(report)
) as xs:boolean {
  let $v := fn:string-join(validate:xsd-info($report, fn:doc($report:SCHEMA)), "&#xA;")
  return if($v) then error($v) else fn:true()
};

(:~
 : Raises an error if content of options map is not correctly typed.
 :
 : @param  $o Options map
 : @param  $apply-report Options map is to be used for report application, i.e. no test function
                         needed then.
 : @return True, if ok.
 :)
declare function check-options(
  $o as map(*),
  $apply-report as xs:boolean
) as xs:boolean {
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

(:~
 : Raises an error with the given message.
 :
 : @param  $msg message
 :)
declare function error(
  $msg as xs:string
) {
  fn:error($report:ERROR, $msg)
};

(:~
 : Generates a random id consisting of digits [0-9] and letters [A-Z][a-z].
 :
 : @return random id string
 :)
declare %private function new-id(
) as xs:string {
  random:uuid()
    ! fn:replace(., '-', '')
    ! xs:hexBinary(.)
    ! xs:base64Binary(.)
    ! xs:string(.)
    ! fn:replace(., '=+$', '')
    ! fn:replace(., "[^A-Za-z0-9]", "_")
};

declare %private function xpath-location(
  $n as node()
) as xs:string {
  fn:replace(fn:path($n), 'Q\{.*?\}root\(\)', '')
};

(:~
 : Escapes characters in location path string.
 :
 : @param  $s location path string
 : @return escaped location path string
 :)
declare %private function escape-location-path-pattern(
  $s as xs:string
) as xs:string {
  $s
    ! fn:replace(., '\[', '\\[')
    ! fn:replace(., '\]', '\\]')
    ! fn:replace(., '\(', '\\(')
    ! fn:replace(., '\)', '\\)')
    ! fn:replace(., '\{', '\\{')
    ! fn:replace(., '\}', '\\}')
};
