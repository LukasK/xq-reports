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
    (: ITEMS :)
    function($rootContext as node()) as node()* { $rootContext//entry },
    (: ID :)
    function($item as node()) as xs:string { $item/@myId/fn:string() },
    (: TEST :)
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
          'new'  : $n,
          'type' : 'warning'
        }
      }
    },
    (: CACHE :)
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

declare %unit:test function reportTest:report-fix-global-element-ordering()
{
  let $doc := document {
    <items>
      <entry myId="id1"><pos>27</pos></entry>
      <entry myId="id3"><pos>4</pos></entry>
      <entry myId="id2"><pos>6</pos></entry>
    </items>
  }
  let $options := reportTest:create-options(
    function($rootContext as node()) as node()* { $rootContext/items/entry },
    function($item as node()) as xs:string { $item/@myId/fn:string() },
    map {
      'id' : 'test-id-global-order',
      'do' : function($items as node()*, $cache as map(*)) as map(*)* {
        let $items := for $i in $items order by number($i/pos/text()) return $i
        for $item at $i in $items
        let $pos := $item/pos
        where number($pos/text()) ne $i
        return map {
          'item' : $item,
          'old'  : $pos,
          'new'  : $pos update (replace value of node . with $i),
          'type' : 'warning'
        }
      }
    },
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-document($report, $doc, $options)
  return unit:assert-equals($cleaned, document {
    <items>
      <entry myId="id1"><pos>3</pos></entry>
      <entry myId="id3"><pos>1</pos></entry>
      <entry myId="id2"><pos>2</pos></entry>
    </items>
  })
};

declare %unit:test function reportTest:report-fix-nested-without-id()
{
  let $doc := document {
    <items>
      <n> text1<n> text2<n/> text3 </n></n>
      text4
      <n> text5<n> text6<n> text7<n><n/> text8 </n></n><n/> text9 </n></n>
    </items>
  }
  let $options := reportTest:create-options(
    function($rootContext as node()) as node()* { $rootContext/items//text() },
    (),
    map {
      'id' : 'test-id-nested-without-id',
      'do' : function($items as node()*, $cache as map(*)) as map(*)* {
        for $item in $items
        let $new := fn:normalize-space($item)
        where $new ne $item
        return map {
          'item' : $item,
          'old'  : $item,
          'new'  : $new,
          'type' : 'warning'
        }
      }
    },
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-document($report, $doc, $options)
  return unit:assert-equals($cleaned, document {
    <items>
      <n>text1<n>text2<n/>text3</n></n>text4<n>text5<n>text6<n>text7<n><n/>text8</n></n><n/>text9</n></n>
    </items>
  })
};


(: ************************* utilities ************************ :)
declare %private function reportTest:create-options(
  $items  as function(node()) as node()*,
  $id     as (function(node()) as xs:string)?,
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
