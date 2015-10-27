# XQ-Reports

Schema-oblivious and customizable XML data reporting and modification.

## TODO
* it is recommended to supply an item-id selector, as report building can be quite slow otherwise, as items cannot be copied

## Prerequisites

You need at least BaseX 8.2.3 to run xq-reports.

## Introduction
### What can I do with xq-reports?

* Reveal inconsistencies in XML data. Fragments or database nodes are all treated the same.
* Serialize a detailed XML report including the problem and eventual recommendations for fixes.
* Use the report for communication, archiving or modify recommended fixes manually.
* Apply a report to the original input data - even if this input has been modified in the meantime.
* Reports are not intended to document simple changes. As a report adds significant overhead, simple diffs might be a better choice.

### Short roundtrip & details

Imagine a fragment (our context) and a report that lists all text nodes on the child axis of each 'entry' element:

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

An `item` is the atomic unit of a report. It represents an arbitrary DOM node within our context. `Items` are identified by their unique `@item-id`, in this case '0'.The `old` element carries the original input node within the subtree of the item. The `@xpath` attribute denotes its location relative to the `item`. The `new` element is optional and recommends a modification of the `item`. If we apply the report to the context, the old node is substituted by the new.

To create a report, we need a minimal configuration (options) in addition to the given context:

```xquery
import module namespace r = 'report';
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

* `ITEM`: The reported item itself. Passing a copy of the item destroys information on its absolute location within the context and leads to unexpected results.
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

The module namespace 'report' is bound to the prefix 'r' in all examples.

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

*Note:* The `@item-id` of an item equals its location within the context, if no `ITEM-ID` option is passed.

### Reporting descendant text nodes of specific elements

### Modifying a document

### Modifying a database

### Modifying items depending on other items (f.i. ordering)

All items identified by the `ITEMS` function within the context are passed to the `TEST` function. This enables us to report items with respect to other items. The following example normalizes the `pos` element:

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



## Reports in Detail
#### Element: report
* **@count**: Number of `item` elements in the report (=reported errors).
* **@time**: Time of creation.
* **@id**: Unique report id.
* **@no-id-selector**: Items to-be-reported are identified via XPath location steps, not ids. As a consequence, changing the input context between the creation and application of a report may lead to unexpected results.
* **@test-id**: Id of the performed test.

#### Element: item
* **@item-id**: Unique Identification of an `item`. Can either be a string value that is unique to the `item`, or a unique XPath location step (see report/@no-id-selector).
* **@xpath**: Location of `new` element relative to the `item` with `@item-id`.
* **old**: Input node at the location `@xpath`, relative to the `item` with `@item-id`.
* **new**: Replacing node sequence (0-*) for the child node of `old`. The child node of `old` is either deleted or replaced with one or several nodes.
* **info**: Additional info for reference.

## Data Modification
#### modification
#### deletion
#### insertion

## Misc
#### Unit Tests
In the base directory run:
`basex -v -t src/test`
#### Preserve whitespaces

## API
