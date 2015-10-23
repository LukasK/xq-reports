(:~
 : Report module tests.
 : @author Lukas Kircher, BaseX GmbH, 2012-14
 :)
module namespace reportTest = 'reportTest';
import module namespace report = 'report';

declare variable $reportTest:DB := $report:TEST;
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
      <item item-id="/n[1]/text()[1]" xpath="" test-id="test1">
        <old><one/>two</old>
      </item>
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          $report:ITEM : $item,
          $report:OLD  : $o,
          $report:NEW  : $n
        }
      }
  }
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items/entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        let $items := for $i in $items order by number($i/pos/text()) return $i
        for $item at $i in $items
        let $pos := $item/pos
        where number($pos/text()) ne $i
        return map {
          $report:ITEM : $item,
          $report:OLD  : $pos,
          $report:NEW  : $pos update (replace value of node . with $i)
        }
      }
  }
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//text() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        let $new := fn:normalize-space($item)
        where $new ne $item
        return map {
          $report:ITEM : $item,
          $report:OLD  : $item,
          $report:NEW  : $new
        }
      }
  }
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          $report:ITEM : $item,
          $report:OLD  : $o,
          $report:NEW  : $n
        }
      }
  }
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          $report:ITEM : $item,
          $report:OLD  : $o,
          $report:NEW  : ()
        }
      }
  }
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        let $fail := fn:not(
          every $t in $item/text() satisfies $t eq fn:normalize-space($t)
        )
        where $fail
        return map {
          $report:ITEM : $item,
          $report:OLD  : $item,
          $report:NEW  : ()
        }
      }
  }
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
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        let $fail := fn:not(
          every $t in $item/text() satisfies $t eq fn:normalize-space($t)
        )
        where $fail
        return map {
          $report:ITEM : $item,
          $report:OLD  : $item,
          $report:NEW  : <entry myId="idXX">default</entry>
        }
      }
  }
  let $report := report:as-xml($doc, $options)
  let $cleaned := report:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="idXX">default</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function reportTest:report-no-new-key()
{
  let $doc :=
    <items>
      <entry myId="id1">text</entry>
    </items>
  let $options := map {
    $report:ITEMS:   function($items as node()) as node()* { $items//entry },
    $report:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $report:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        return map {
          $report:ITEM : $item,
          $report:OLD  : $item
        }
      }
  }
  let $report := report:as-xml($doc, $options)
  return unit:assert(fn:empty($report/item/new))
};
