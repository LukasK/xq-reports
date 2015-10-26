# XQuery/XML  Data Reporting Module

Schema-oblivious and customizable XML data reporting and modification.

## TODO
* it is recommended to supply an item-id selector, as report building can be quite slow otherwise, as items cannot be copied

## Introduction
#### What can I do with xq-reports?

* Reveal inconsistencies in XML data. Fragments or database nodes are all treated the same.
* Serialize a detailed XML report including the problem and eventual recommendations for fixes.
* Use the report for communication, archiving or modify recommended fixes manually.
* Apply a report to the original input data - even if this input has been modified in the meantime.

#### More details please?

Imagine a simple report listing all nodes that have some text on the child axis:

```xml
<report count="1" test-id="test1">
  <item item-id="/node1[1]" xpath="">
    <old><node1>with some text</node1></old>
    <new><node1>modified text</node1></new>
  </item>
</report>
```

An `item` is the atomic unit of a report. It represents an arbitrary DOM node in an XML document. `Items` are identified by their unique `@item-id`, in this case an XPath location step. The `old` element shows the original input `item`. The `new` element is optional and recommends a modification of the `item`. If we apply the report to the input, the old `item` is substituted by the new.

## Quick Examples
#### Normalizing text nodes in an arbitrary context
```xquery
import module namespace report = 'report';
report:as-xml(
  (: input document :)
  <items>
    <n> text1<n> text2<n/></n></n>
  </items>,
  (: options map :)
  map {
    'items-selector' : function($context) { $context//text() },
    'test-id'        : 'test1',
    'test'           : function($texts, $cache) {
      for $old in $texts
      let $new := fn:normalize-space($old)
      where $new ne $old
      return map {
        'item' : $old,
        'old'  : $old,
        'new'  : $new
      }
    },
    'recommend': fn:true()
  }
)

```

Result:

```xml
<report count="2" time="2015-01-28T17:07:24.387Z" id="X2aJME9uRryIMXM92XXjrA" no-id-selector="true" test-id="test1">
  <item item-id="/n[1]/text()[1]" xpath="">
    <old> text1</old>
    <new>text1</new>
  </item>
  <item item-id="/n[1]/n[1]/text()[1]" xpath="">
    <old> text2</old>
    <new>text2</new>
  </item>
</report>
```
#### Reporting descendant text nodes of specific elements
#### Modifying a document
#### Modifying a database
#### Modifying items depending on other items (f.i. ordering)
#### Using caches

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
