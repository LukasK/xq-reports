(:~
 : Report module tests.
 :
 : @author Lukas Kircher, BaseX GmbH, 2015
 : @license BSD 2-Clause License
 :)
module namespace t = 't';
import module namespace xq-reports = 'xq-reports' at '../main/xq-reports.xqm';

declare variable $t:DB := $xq-reports:TEST;
declare variable $t:INPUT := file:base-dir() || '../../etc/data/test.xml';

declare %unit:before %updating function t:prep()
{
  db:create($t:DB, $t:INPUT)
};

declare %unit:after-module %updating function t:clean()
{
  db:drop($t:DB)
};

declare %unit:test('expected', 'xq-reports:XQREP01') function t:modify-context-root()
{
  xq-reports:as-xml(
    <node/>,
    map {
      $xq-reports:ITEMS: function($ctx as node()) as node()* { $ctx },
      $xq-reports:TEST:
        function($items as node()*, $cache as map(*)?) as map(*)* {
          for $item in $items
          return map {
            $xq-reports:ITEM : $item,
            $xq-reports:OLD  : $item,
            $xq-reports:NEW  : <node1/>
          }
        }
    }
  )
};

declare %unit:test function t:fix-simple-text()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $o,
          $xq-reports:NEW  : text {$n}
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1">text1.1<sth/>text1.2</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function t:fix-global-element-ordering()
{
  let $doc :=
    <items>
      <entry myId="id1"><pos>27</pos></entry>
      <entry myId="id3"><pos>4</pos></entry>
      <entry myId="id2"><pos>6</pos></entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx/entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        let $items := for $i in $items order by number($i/pos/text()) return $i
        for $item at $i in $items
        let $pos := $item/pos
        where number($pos/text()) ne $i
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $pos,
          $xq-reports:NEW  : $pos update (replace value of node . with $i)
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1"><pos>3</pos></entry>
      <entry myId="id3"><pos>1</pos></entry>
      <entry myId="id2"><pos>2</pos></entry>
    </items>
  )
};

declare %unit:test function t:clean-nested-texts-without-id()
{
  let $doc :=
    <items>
      <n> text1<n> text2<n/> text3 </n></n>
      text4
      <n> text5<n> text6<n> text7<n><n/> text8 </n></n><n/> text9 </n></n>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//text() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        let $new := fn:normalize-space($item)
        where $new ne $item
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $item,
          $xq-reports:NEW  : text {$new}
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <n>text1<n>text2<n/>text3</n></n>text4<n>text5<n>text6<n>text7<n><n/>text8</n></n>
      <n/>text9</n></n>
    </items>
  )
};

declare %unit:before('apply-to-database') %updating function t:apply-to-database-update()
{
  let $doc := db:open($t:DB)//apply-to-database-update/items
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $o,
          $xq-reports:NEW  : text {$n}
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  return xq-reports:apply($report, $doc, $options)
};
declare %unit:test function t:apply-to-database-test()
{
  let $cleaned := db:open($t:DB)//apply-to-database-update/items
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1">text1.1<sth/>text1.2</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function t:delete-item-1()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item/text()
        let $n := fn:normalize-space($o)
        where $n ne $o
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $o,
          $xq-reports:NEW  : ()
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id1"><sth/></entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function t:delete-item-2()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        let $fail := fn:not(
          every $t in $item/text() satisfies $t eq fn:normalize-space($t)
        )
        where $fail
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $item,
          $xq-reports:NEW  : ()
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function t:replace-entry()
{
  let $doc :=
    <items>
      <entry myId="id1">text1.1  <sth/> text1.2 </entry>
      <entry myId="id2">text2</entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        where fn:not(every $t in $item/text() satisfies $t eq fn:normalize-space($t))
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $item,
          $xq-reports:NEW  : <entry myId="idXX">default</entry>
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return unit:assert-equals($cleaned,
    <items>
      <entry myId="idXX">default</entry>
      <entry myId="id2">text2</entry>
    </items>
  )
};

declare %unit:test function t:test-result-without-new()
{
  let $doc :=
    <items>
      <entry myId="id1">text</entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $item
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  return unit:assert(fn:empty($report/item/new))
};

declare %unit:test function t:context-with-namespaces()
{
  let $doc :=
    <items>
      <entry myId="id0">
        <data><BEFORE/></data>
      </entry>
      <entry xmlns="ns" myId="id1">
        <data xmlns="ns2"><BEFORE xmlns="ns3"/><BEFORE/></data>
      </entry>
      <entry xmlns="ns" myId="id3">
        <data xmlns="ns3"><BEFORE/></data>
      </entry>
      <entry myId="id2"><BEFORE/></entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//*:entry },
    $xq-reports:ITEMID:  function($item as node()) as xs:string { $item/@myId/fn:string() },
    $xq-reports:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $o in $item//*:BEFORE
        return map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $o,
          $xq-reports:NEW  : <AFTER/>
        }
      }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return (
    unit:assert-equals(fn:count($cleaned//*:BEFORE), 0),
    unit:assert-equals(fn:count($cleaned//*:AFTER), 5)
  )
};

declare %unit:test function t:access-cache()
{
  let $doc :=
    <items>
      <entry myId="id0">text</entry>
    </items>
  let $options := map {
    $xq-reports:ITEMS:   function($ctx as node()) as node()* { $ctx//entry },
    $xq-reports:TEST:
      function($item as node()*, $cache as map(*)?) as map(*)* {
        map {
          $xq-reports:ITEM : $item,
          $xq-reports:OLD  : $item/text(),
          $xq-reports:NEW  : text {$cache('new-text')}
        }
      },
    $xq-reports:CACHE: map { 'new-text': 'foo' }
  }
  let $report := xq-reports:as-xml($doc, $options)
  let $cleaned := xq-reports:apply-to-copy($report, $doc, $options)
  return (
    unit:assert-equals($cleaned/entry/text(), text { 'foo' })
  )
};


(: ----------------------- options map / test result types tests -------------------------------- :)

declare %private function t:check-options-setup($options) {
  xq-reports:as-xml(
    <database>
      <node/>
    </database>,
    $options
  )
};

declare %unit:test('expected', 'xq-reports:XQREP02') function t:invalid-options()
{
  t:check-options-setup(
    map {
      (: invalid ITEMS :)
      $xq-reports:ITEMS: function() { <node/> },
      $xq-reports:TEST: function($items as node()*, $cache as map(*)?) as map(*)* { () }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP02') function t:invalid-options-2()
{
  t:check-options-setup(
    (: TEST missing :)
    map {
      $xq-reports:ITEMS: function($ctx as node()) as node()* { $ctx//node }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP02') function t:invalid-options-3()
{
  t:check-options-setup(
    (: ITEMS missing :)
    map {
      $xq-reports:TEST: function($items as node()*, $cache as map(*)?) as map(*)* { () }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP02') function t:invalid-options-4()
{
  t:check-options-setup(
    (: ITEMID invalid :)
    map {
      $xq-reports:ITEMS: function($ctx as node()) as node()* { $ctx//node },
      $xq-reports:ITEMID: function() { 'item-id' },
      $xq-reports:TEST: function($items as node()*, $cache as map(*)?) as map(*)* { () }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP03') function t:invalid-test-result()
{
  xq-reports:as-xml(
    <database>
      <node/>
    </database>,
    map {
      $xq-reports:ITEMS: function($ctx as node()) as node()* { $ctx//node },
      $xq-reports:TEST:
        function($items as node()*, $cache as map(*)?) as map(*)* {
          for $item in $items
          return map {
            (: test invalid ITEM :)
            $xq-reports:ITEM : 'should be a node, not a string',
            $xq-reports:OLD  : $item,
            $xq-reports:NEW  : <newItem/>
          }
        }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP03') function t:invalid-test-result-2()
{
  xq-reports:as-xml(
    <database>
      <node/>
    </database>,
    map {
      $xq-reports:ITEMS: function($ctx as node()) as node()* { $ctx//node },
      $xq-reports:TEST:
        function($items as node()*, $cache as map(*)?) as map(*)* {
          for $item in $items
          return map {
            $xq-reports:ITEM : $item,
            (: test invalid OLD :)
            $xq-reports:OLD  : 'should be a node, not a string',
            $xq-reports:NEW  : <newItem/>
          }
        }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP03') function t:invalid-test-result-3()
{
  xq-reports:as-xml(
    <database>
      <node/>
    </database>,
    map {
      $xq-reports:ITEMS: function($ctx as node()) as node()* { $ctx//node },
      $xq-reports:TEST:
        function($items as node()*, $cache as map(*)?) as map(*)* {
          for $item in $items
          return map {
            $xq-reports:ITEM : $item,
            $xq-reports:OLD  : $item,
            (: test invalid NEW :)
            $xq-reports:NEW  : 'should be a node, not a string'
          }
        }
    }
  )
};

declare %unit:test('expected', 'xq-reports:XQREP04') function t:invalid-invalid-report()
{
  (: @xpath attribute missing :)
  xq-reports:validate(db:open($t:DB)//invalid-report/report)
};
