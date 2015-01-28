module namespace reportTest = 'reportTest';
import module namespace report = 'report';

declare variable $reportTest:DB := 'test';
declare variable $reportTest:INPUT := file:base-dir() || '../../etc/data/test.xml';

declare %unit:before %updating function reportTest:prep()
{
  db:create($reportTest:DB, $reportTest:INPUT)
};

declare %unit:after-module %updating function reportTest:clean()
{
  db:drop($reportTest:DB)
};

(:declare %unit:test('expected', 'XQREPORT') function reportTest:report-schema-error1()
{
  report:validate(
    <report count="1" time="2015-01-28T15:02:07.342Z" id="3SgsPhTIQHuM_hcg7_rEXw" no-id-selector="true">
      <hit item-id="/n[1]/text()[1]" xpath="" test-id="test1">
        <old><one/>two</old>
      </hit>
    </report>
  )
};:)

declare %unit:test function reportTest:report-fix-simple-text()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := reportTest:create-options(
    (: ITEMS :)
    function($items as node()) as node()* { $items//entry },
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
          'new'  : $n
        }
      }
    },
    fn:true(),
    (: CACHE :)
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1">text1.1<sth/>text1.2</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function reportTest:report-fix-global-element-ordering()
{
  let $doc :=
    <items>
      <entry myId="id1"><pos>27</pos></entry>
      <entry myId="id3"><pos>4</pos></entry>
      <entry myId="id2"><pos>6</pos></entry>
    </items>
  let $options := reportTest:create-options(
    function($items as node()) as node()* { $items/entry },
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
          'new'  : $pos update (replace value of node . with $i)
        }
      }
    },
    fn:true(),
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1"><pos>3</pos></entry>
      <entry myId="id3"><pos>1</pos></entry>
      <entry myId="id2"><pos>2</pos></entry>
    </items>
  )
};

declare %unit:test function reportTest:report-fix-nested-without-id()
{
  let $doc :=
    <items>
      <n> text1<n> text2<n/> text3 </n></n>
      text4
      <n> text5<n> text6<n> text7<n><n/> text8 </n></n><n/> text9 </n></n>
    </items>
  let $options := reportTest:create-options(
    function($items as node()) as node()* { $items//text() },
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
          'new'  : $new
        }
      }
    },
    fn:true(),
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <n>text1<n>text2<n/>text3</n></n>text4<n>text5<n>text6<n>text7<n><n/>text8</n></n><n/>text9</n></n>
    </items>
  )
};

declare %unit:before('apply-to-database') %updating function reportTest:apply-to-database-update()
{
  let $doc := db:open($reportTest:DB)//apply-to-database-update/items
  let $options := reportTest:create-options(
    (: ITEMS :)
    function($items as node()) as node()* { $items//entry },
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
          'new'  : $n
        }
      }
    },
    fn:true(),
    map {}
  )
  let $report := report:as-xml($doc, $options)
  return report:apply($report, $doc, $options)
};
declare %unit:test function reportTest:apply-to-database-test()
{
  let $cleaned := db:open($reportTest:DB)//apply-to-database-update/items
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1">text1.1<sth/>text1.2</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function reportTest:report-delete-item()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := reportTest:create-options(
    function($items as node()) as node()* { $items//entry },
    function($item as node()) as xs:string { $item/@myId/fn:string() },
    map {
      'id' : 'test-id-delete',
      'do' : function($items as node()*, $cache as map(*)) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          'item' : $item,
          'old'  : $o,
          'new'  : ()
        }
      }
    },
    fn:true(),
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1"><sth/></entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function reportTest:report-delete-item2()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := reportTest:create-options(
    function($items as node()) as node()* { $items//entry },
    function($item as node()) as xs:string { $item/@myId/fn:string() },
    map {
      'id' : 'test-id-delete',
      'do' : function($items as node()*, $cache as map(*)) as map(*)* {
        for $item in $items
        let $fail := fn:not(
          every $t in $item/text() satisfies $t eq fn:normalize-space($t)
        )
        where $fail
        return map {
          'item' : $item,
          'old'  : $item,
          'new'  : ()
        }
      }
    },
    fn:true(),
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function reportTest:report-delete-replace()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := reportTest:create-options(
    function($items as node()) as node()* { $items//entry },
    function($item as node()) as xs:string { $item/@myId/fn:string() },
    map {
      'id' : 'test-id-delete',
      'do' : function($items as node()*, $cache as map(*)) as map(*)* {
        for $item in $items
        let $fail := fn:not(
          every $t in $item/text() satisfies $t eq fn:normalize-space($t)
        )
        where $fail
        return map {
          'item' : $item,
          'old'  : $item,
          'new'  : <entry myId="idXX">default</entry>
        }
      }
    },
    fn:true(),
    map {}
  )
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="idXX">default</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};



(: ************************* utilities ************************ :)
declare %private function reportTest:create-options(
  $items     as function(node()) as node()*,
  $id        as (function(node()) as xs:string)?,
  $test      as map(*),
  $recommend as xs:boolean,
  $cache     as map(*))
  as map(*)
{
  map {
    'items-selector' : $items,
    'id-selector'    : $id,
    'test'           : $test,
    'recommend'      : $recommend,
    'cache'          : $cache
  }
};
