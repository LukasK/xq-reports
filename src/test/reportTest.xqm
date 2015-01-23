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
    function($rootContext as node()) as node()* { $rootContext//entry },
    function($item as node()) as xs:string { $item/@myId/fn:string() },
(:    function(node(), map(*)):)
    map {
      'id' : 'test-id-normalize-ws',
      'do' : function($items as node()*, $cache as map(*)) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          'item' : $item,
          'old'  : $o,
          'new'  : $n
        }
      }
    },
    map {}
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

declare %private function reportTest:create-options(
  $items  as function(node()) as node()*,
  $id     as function(node()) as xs:string,
  $test   as map(*),
  $cache  as map(*))
  as map(*)
{
  map {
    'items-selector' : $items,
    'id-selector'    : $id,
    'test'           : $test,
    'cache'          : $cache
  }
};
