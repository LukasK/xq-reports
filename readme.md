# XQuery/XML  Data Reporting Module

Schema-oblivious and customizable XML data reporting and modification.

#### What can I do with xq-reports?

* Reveal inconsistencies in XML data. Fragments or database nodes are all treated the same.
* Serialize a detailed XML report including the problem and eventual recommendations for fixes.
* Use the report for communication, archiving or modify recommended fixes manually.
* Apply a report to the original input data - even if this input has been modified in the meantime.

#### Prerequisites

BaseX 8.0 (sure?)

## Quick Examples
#### Most basic example

Report all non-normalized text nodes in an arbitrary context.

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
    'test'           : map {
      'id': 'test1',
      'do': function($texts, $cache) {
        for $old in $texts
        let $new := fn:normalize-space($old)
        where $new ne $old
        return map {
          'item' : $old,
          'old'  : $old,
          'new'  : $new
        }
      }
    }
  }
)
```

Result:

```xml
<report count="2" time="2015-01-28T15:02:07.342Z" id="3SgsPhTIQHuM_hcg7_rEXw" no-id-selector="true" test-id="test1">
  <hit item-id="/n[1]/text()[1]" xpath="">
    <old> text1</old>
  </hit>
  <hit item-id="/n[1]/n[1]/text()[1]" xpath="">
    <old> text2</old>
  </hit>
</report>
```
#### Reporting descendant text nodes of specific elements
#### Modifying a document
#### Modifying a database
#### Modifying items depending on other items
#### Using caches

## Reports in Detail
#### Element: report
* **@count**: Number of `hit` elements in the report (=reported errors).
* **@time**: Time of creation.
* **@id**: Unique report id.
* **@no-id-selector**: Items to-be-reported are identified via XPath location steps, not ids. As a consequence, changing the input context between the creation and application of a report may lead to unexpected results.
* **@test-id**: Id of the performed test.

#### Element: hit
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
