module namespace reportTest = 'reportTest';

import module namespace report = 'report';

declare %unit:test function reportTest:report-fix-simple-text()
{
  let $doc := document {
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  }
  let $options := reportTest:create-options(
    function($rootContext as node()) as node()* {
      $rootContext//entry
    },
    function($item as node()) as xs:string {
      $item/@myId/fn:string()
    },
    'test-id-normalize-ws',
    function($entry as node(), $cache as map(*)) as node()* {
      for $t in $entry/text()
      where fn:normalize-space($t) ne $t
      return $t
    },
    function($node as node(), $cache as map(*)) as node()* {
      text { fn:normalize-space($node) }
    },
    map {
    }
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-document($report, $doc, $options)
  return unit:assert-equals($cleaned, document {
    <items>
      <entry myId="id1">text1.1<sth/>text1.2</entry>
      <entry myId="id2">text2</entry>
    </items>
  })
};

declare %unit:test function reportTest:report-fix-simple-element()
{
  ()
};

declare %private function reportTest:create-options(
  $item   as function(node()) as node()*,
  $id     as function(node()) as xs:string,
  $testId as xs:string,
  $test   as function(node(), map(*)) as node()*,
  $fix    as function(node(), map(*)) as node()*,
  $cache  as map(*))
  as map(*)
{
  map {
    'item-selector' : $item,
    'id-selector'   : $id,
    'test'          : ($testId, $test),
    'fix'           : $fix,
    'cache'         : $cache
  }
};
