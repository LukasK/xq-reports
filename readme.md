# xq-reports
Schema-oblivious and customizable XML data reporting and modification.

## Prerequisites

You need at least BaseX 8.2.3 to run xq-reports.

## What can I do with xq-reports?

* Reveal inconsistencies in XML data. Fragments or database nodes are all treated the same.
* Serialize a detailed XML report including the problem and eventual recommendations for fixes.
* Use the report for communication, archiving or modify recommended fixes manually.
* Apply a report to the original input data - even if this input has been modified in the meantime.
* Reports are not intended to document simple changes. As a report adds significant overhead, 
  simple diffs might be a better choice.

## Short roundtrip & details

Imagine a fragment (our context) and a report that lists all text nodes on the child axis of each
'entry' element:

```xml
<entries>
  <entry id="0">with some text</entry>
</entries>
```

```xml
<report count="1" time="..." id="..." no-id-selector="false" test-id="">
  <item item-id="0">
    <old xpath="/text()[1]">with some text</old>
    <new>with modified text</new>
  </item>
</report>
```

An `item` is the atomic unit of a report. It represents an arbitrary DOM node within our context.
`Items` are identified by their unique `@item-id`, in this case '0'.The `old` element carries the
original input node within the subtree of the item. The `@xpath` attribute denotes its location
relative to the `item`. The optional `new` element recommends a modification of the `item`. If we
apply the report to the context, the old node is substituted by the new.

To create a report, we need a minimal configuration (options) in addition to the given context:

```xquery
import module namespace r = 'xq-reports';
r:as-xml(
  $context,
  map {
    $r:ITEMS  : function($context as node()) as node()* { $context//entry },
    $r:ITEMID : function($item as node()) as xs:string { $item/@id/fn:string() },
    $r:TEST   :
      function($items as node()*, $cache as map(*)?) as map(*)* {
        for $item in $items
        for $text in $item/child::text()
        return map {
          $r:ITEM : $item,
          $r:OLD  : $text,
          $r:NEW  : text { 'with modified text' }
        }
      }
  }
)
```

The configuration consists of a map holding several function items.

* `ITEMS`: Is evaluated on the given context and returns all items to be tested.
* `ITEMID`: Is evaluated on each item and returns its unique id.
* `TEST`: Tests each item and eventually returns a report item, again as a map.

In case an item is reported the resulting map contains the following:

* `ITEM`: The reported item itself. Passing a copy of the item destroys information on its absolute
          location within the context and leads to unexpected results.
* `OLD`: The reported node within the subtree of the item. Again, do not pass a copy of this node.
* `NEW`: A substituting sequence of nodes.

To modify our context, we simply pass the generated report, original context and options:

```xquery
r:apply-to-copy($report, $context, $options)
```

Result:

```xml
<entries>
  <entry id="0">with modified text</entry>
</entries>
```

## Quick Examples

The module namespace 'xq-reports' is bound to the prefix 'r' in all examples.

### Normalizing all text nodes in an arbitrary context
```xquery
r:as-xml(
  <items>
    <n> text1<n> text2<n/></n></n>
  </items>,
  map {
    $r:ITEMS  : function($context) { $context//text() },
    $r:TEST   :
      function($texts, $cache) {
        for $old in $texts
        let $new := fn:normalize-space($old)
        where $new ne $old
        return map {
          $r:ITEM : $old,
          $r:OLD  : $old,
          $r:NEW  : $new
        }
      }
  }
)
```

Result:

```xml
<report count="2" time="..." id="..." no-id-selector="true" test-id="">
  <item item-id="/Q{}n[1]/text()[1]">
    <old xpath=""> text1</old>
    <new>text1</new>
  </item>
  <item item-id="/Q{}n[1]/Q{}n[1]/text()[1]">
    <old xpath=""> text2</old>
    <new>text2</new>
  </item>
</report>
```

*Note:* The `@item-id` of an item equals its location within the context, if no `ITEM-ID` option
is passed.

### Modifying items depending on other items (f.i. ordering)

All items identified by the `ITEMS` function within the context are passed to the `TEST` function.
This enables us to report items with respect to other items. The following example normalizes the
`pos` element:

```xquery
r:as-xml(
  <items>
    <entry id="id1"><pos>27</pos></entry>
    <entry id="id3"><pos>4</pos></entry>
    <entry id="id2"><pos>6</pos></entry>
  </items>,
  map {
    $r:ITEMS:   function($ctx as node()) as node()* { $ctx/entry },
    $r:ITEMID:  function($item as node()) as xs:string { $item/@id/fn:string() },
    $r:TEST:
      function($items as node()*, $cache as map(*)?) as map(*)* {
        let $items := for $i in $items order by number($i/pos/text()) return $i
        for $item at $i in $items
        let $pos := $item/pos
        where number($pos/text()) ne $i
        return map {
          $r:ITEM : $item,
          $r:OLD  : $pos,
          $r:NEW  : element pos { $i }
        }
      }
  }
)
```

```xml
<report count="3" time="..." id="..." no-id-selector="false" test-id="">
  <item item-id="id3">
    <old xpath="/Q{}pos[1]">
      <pos>4</pos>
    </old>
    <new>
      <pos>1</pos>
    </new>
  </item>
  <item item-id="id2">
    <old xpath="/Q{}pos[1]">
      <pos>6</pos>
    </old>
    <new>
      <pos>2</pos>
    </new>
  </item>
  <item item-id="id1">
    <old xpath="/Q{}pos[1]">
      <pos>27</pos>
    </old>
    <new>
      <pos>3</pos>
    </new>
  </item>
</report>
```

### Using caches

An optional cache can be passed to the options map. The Benefits are for example simple reuse of
existing code and increased performance.

```xquery
r:as-xml(
  <database>
    <person id="0" name="Christoph"/>
    <person id="1" name="Maria"/>
  </database>,
  map {
    $r:ITEMS  : function($context as node()) as node()* { $context//person },
    $r:ITEMID : function($item as node()) as xs:string { $item/@id/fn:string() },
    $r:TEST   :
      function($items as node()*, $cache as map(*)?) as map(*)* {
        let $professions := $cache?professions
        for $item in $items
        let $item-new := $item update (
          insert node attribute profession { $professions($item/@id) } into .
        )
        return map {
          $r:ITEM : $item,
          $r:OLD  : $item,
          $r:NEW  : $item-new
        }
      },
    $r:CACHE  : map {
      "professions" : map {
        "0": "physiotherapist",
        "1": "chemist"
      }
    }
  }
)
```

```xml
<report count="2" time="2015-11-19T09:46:05.348+01:00" id="GzEpK6oLS7uC5G5pmduLEw" no-id-selector="false" test-id="">
  <item item-id="0">
    <old xpath="">
      <person id="0" name="Christoph"/>
    </old>
    <new>
      <person profession="physiotherapist" id="0" name="Christoph"/>
    </new>
  </item>
  <item item-id="1">
    <old xpath="">
      <person id="1" name="Maria"/>
    </old>
    <new>
      <person profession="chemist" id="1" name="Maria"/>
    </new>
  </item>
</report>
```

## Reports in Detail
#### Element: report
* **@count**: Number of `item` elements in the report (=reported errors).
* **@time**: Time of creation.
* **@id**: Unique report id.
* **@no-id-selector**: If true, Items to-be-reported are identified exclusively via XPath location
  steps, no ids. As a consequence, changing the input context between the creation and application 
  of a report may lead to unexpected results. It is recommended to supply an item-id selector, as
  this may significantly speed up the creation of a report.
* **@test-id**: Id of the performed test.

#### Element: item
* **@item-id**: Unique Identification of an `item`. Can either be a string value that is unique to
  the `item`, or a unique XPath location step (see report/@no-id-selector).
* **@xpath**: Location of `old` element relative to the `item` with `@item-id`.
* **old**: Input node at the location `@xpath`, relative to the `item` with `@item-id`.
* **new**: Substituting node sequence (0-*). The child node of `old` is either deleted or replaced
  with one or several nodes.
* **info**: Additional info for reference.

## Unit Tests
In the base directory run:
`basex -v -t src/test`

## API
### as-xml
```xquery
r:as-xml(
  $root-context as node(),
  $options as map(*)
) as element(report)
```

Creates an XML report. A minimal options map contains key/value pairs for: $r:ITEMS, $r:TEST.

### apply
```xquery
r:apply(
  $report as element(report),
  $root-context as node(),
  $options as map(*)
) as empty-sequence()
```

Applies a report to the given context. The context can be a fragment or a database node. A minimal
options map contains key/value pairs for: $r:ITEMS

### apply-to-copy
```xquery
r:apply-to-copy(
  $report as element(report),
  $root-context as node(),
  $options as map(*)
) as node()
```

Applies a report to a copy of the given context and returns the copy. A minimal options map
contains key/value pairs for: $r:ITEMS

### Options map
All reporting functions accept an options map for report customization. All possible key/value pairs
are listed below. The Keys are declared as variables and are bound to the `xq-reports` module
namespace. See examples for further reference.

### Option: ITEMS
```xquery
function(node()) as node()*
```

Takes the root context and returns items to be tested.

### Option: ITEMID
```xquery
(function(node()) as xs:string)?
```

Takes an item and returns its unique id.

### Option: TEST
```xquery
function(node()*, map(*)?) as map(*)*
```

Takes all identified items within the context and returns one result map per reported item with the
following key/value pairs. Keys are again bound to the `xq-reports` module namespace.

* `$r:ITEM as node()`: The item to be reported (don't pass copies!)
* `$r:OLD as node()`: The reported node within the item subtree (again, don't pass copies!)
* `$r:NEW as node()*`: Recommended substituting node sequence
* `$r:INFO as node()*`: Additional information node sequence

### Option: TESTID
```xquery
xs:string?
```

Identifier of test function

### Option: CACHE
```xquery
map(*)?
```

Cache to leverage code reuse/evaluation speedups.
