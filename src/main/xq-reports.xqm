(:~
 : Report module.
 :
 : @author Lukas Kircher, BaseX GmbH, 2015
 : @version 0.1
 : @license BSD 2-Clause License
 :)
module namespace xq-reports = 'xq-reports';
declare default function namespace 'xq-reports';

(:
TODO
* unit tests
  * expected fails
:)

declare variable $xq-reports:ERROR := xs:QName("xq-reports:XQREP01");
declare variable $xq-reports:OPTIONS-ERROR := xs:QName("xq-reports:XQREP02");
declare variable $xq-reports:TEST-RETURN-ERROR := xs:QName("xq-reports:XQREP03");
declare variable $xq-reports:SCHEMA-ERROR := xs:QName("xq-reports:XQREP04");
declare variable $xq-reports:SCHEMA := file:base-dir() || '../../etc/report.xsd';

(: option keys :)
declare variable $xq-reports:ITEMS  := 'items-selector';
declare variable $xq-reports:ITEMID := 'id-selector';
declare variable $xq-reports:TEST   := 'test';
declare variable $xq-reports:TESTID := 'test-id';
declare variable $xq-reports:CACHE  := 'cache';
(: test result keys :)
declare variable $xq-reports:ITEM   := 'item';
declare variable $xq-reports:OLD    := 'old';
declare variable $xq-reports:NEW    := 'new';
declare variable $xq-reports:INFO   := 'info';

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
  check-options($options, fn:false()),
  let $timestamp := fn:current-dateTime()
  (: options :)
  let $id-selector-f := $options($xq-reports:ITEMID)
  let $no-id-selector := fn:empty($id-selector-f)
  let $items := $options($xq-reports:ITEMS)($root-context)
  let $err := if(fn:count($items) eq 1 and $items is $root-context) then
    error($xq-reports:ERROR, 'The context root cannot be the direct target of a report') else ()
  let $cache := $options($xq-reports:CACHE)
  let $test-id := $options($xq-reports:TESTID)
  let $test-f := $options($xq-reports:TEST)

  (: if item-id selector is given, items can be copied for substantial speedup :)
  let $items := if($no-id-selector) then $items else $items ! (. update ())
  let $reported-items :=
    for $hit in $test-f($items, $cache)
    return (
      check-test-function-return($hit),
      (: only make a recommendation if test function returned a NEW key/value pair :)
      let $new-key := map:keys($hit) = $xq-reports:NEW
      let $item := $hit($xq-reports:ITEM)
      let $old  := $hit($xq-reports:OLD)
      let $new  := $hit($xq-reports:NEW)
      let $info := $hit($xq-reports:INFO)
      let $item-location := xpath-location($item)
      return element item {
        attribute item-id {
          if($no-id-selector) then $item-location else $id-selector-f($item)
        },
        element old {
          (: determine path of 'old' node relative to item :)
          attribute xpath {
            if($no-id-selector) then
              fn:replace(xpath-location($old), escape-location-path-pattern($item-location), '')
            else
              xpath-location($old)
          },
          $old
        },
        element new { $new }[$new-key],
        element info { $info }[fn:exists($info)]
      }
    )
    
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
  check-options($options, fn:true()),
  validate($report),
  let $no-id-selector := xs:boolean($report/@no-id-selector)
  let $reported-items := $report/item
  let $item-id-f := $options($xq-reports:ITEMID)
  (: loop through possible items in root context :)
  for $item in $options($xq-reports:ITEMS)($root-context)
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
  where fn:exists($new)
  let $new := $new/child::node()
  let $old := $reported-item/old/child::node()
  let $target := xquery:eval("." || $reported-item/old/@xpath, map { '': $item })
  return
    (: safety measure - throw error in case original already changed :)
    if(fn:not(fn:deep-equal($old, $target))) then
      db:output(error($xq-reports:ERROR, "Report recommendation is outdated: " || $reported-item))
    else if(fn:count($old) ne 1) then
      db:output(error($xq-reports:ERROR, "Old element must have one child node: "|| $reported-item))
    else
      (: if $new empty -> delete, else -> replace with $new sequence :)
      replace node $target with $new
};

(:~
 : Valdiates a report element.
 :
 : @param  $report XML report
 : @return Empty sequence, if report ok.
 :)
declare function validate(
  $report as element(report)
) as empty-sequence() {
  let $v := fn:string-join(validate:xsd-info($report, fn:doc($xq-reports:SCHEMA)), "&#xA;")
  return if($v) then
    error($xq-reports:SCHEMA-ERROR, $v)
  else
    ()
};

(:~
 : Raises an error if content of options map is not correctly typed.
 :
 : @param  $o Options map
 : @param  $apply-report Options map is to be used for report application, i.e. no test function
                         needed then.
 : @return Empty sequence, if ok. Else raise error.
 :)
declare function check-options(
  $o as map(*),
  $apply-report as xs:boolean
) as empty-sequence() {
  let $e := function($k) {
    error($xq-reports:OPTIONS-ERROR, 'Type of option invalid or option missing: ' || $k)
  }
  return
    if(fn:not($o($xq-reports:ITEMS) instance of function(node()) as node()*)) then
      $e('ITEMS')
    else if(fn:not($o($xq-reports:ITEMID) instance of (function(node()) as xs:string)?)) then
      $e('ITEMID')
    else if(fn:not($o($xq-reports:TESTID) instance of xs:string?)) then
      $e('TESTID')
    else if(fn:not($o($xq-reports:CACHE) instance of map(*)?)) then
      $e('CACHE')
    else if(fn:not($o($xq-reports:TEST) instance of function(node()*, map(*)?) as map(*)*)
    and fn:not($apply-report)) then
      $e('TEST')
    else ()
};

(:~
 : Raises an error if the returned map of a test function is not correctly typed.
 :
 : @param  $o test result map
 : @return Empty sequence, if ok. Else raise error.
 :)
declare function check-test-function-return(
  $m as map(*)
) as empty-sequence() {
  let $e := function($k) {
    error($xq-reports:TEST-RETURN-ERROR, 'Invalid test result (key=' || $k || '): ' || $m($k))
  }
  return
    if(fn:not($m($xq-reports:ITEM) instance of node())) then
      $e($xq-reports:ITEM)
    else if(fn:not($m($xq-reports:OLD) instance of node())) then
      $e($xq-reports:OLD)
    else if(fn:not($m($xq-reports:NEW) instance of node()*)) then
      $e($xq-reports:NEW)
    else if(fn:not($m($xq-reports:INFO) instance of node()*)) then
      $e($xq-reports:INFO)
    else ()
};

(:~
 : Raises an error with the given message.
 :
 : @param  $type error type
 : @param  $msg message
 :)
declare function error(
  $type as xs:QName,
  $msg as xs:string
) {
  fn:error($type, $msg)
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
