module namespace reportTest = 'reportTest';

import module namespace report = 'report';

declare variable $reportTest:TEST1-DOC := document {
  element items {
    element entry {
      attribute myId { 'id1' },
      'text1.1  ',
      element sth {},
      ' text1.2 '
    },
    element entry {
      attribute myId { 'id2' },
      'text2'
    }
  }
};
declare variable $reportTest:TEST1-SETUP := map {
  'item-selector': function($rootContext as item()) as element(entry)* {
    $rootContext//entry
  },
  'id-selector': function($item as element()) {
    $item/@myId/fn:string()
  },
  'test': ('normalize ws', function($entry as element()) {
    for $t in $entry/text()
    where fn:normalize-space($t) ne $t
    return $t
  }),
  'fix': function($node as node(), $cache as map(*)) {
    fn:normalize-space($node)
  },
  'cache': map {
  }
};

declare %unit:test function reportTest:as-xml()
{
  let $report := report:as-xml($reportTest:TEST1-DOC, $reportTest:TEST1-SETUP)
  let $cleaned := report:apply-to-document($report, $reportTest:TEST1-DOC, $reportTest:TEST1-SETUP)
  return unit:assert-equals($cleaned, document {
    element items {
      element entry {
        attribute myId { 'id1' },
        'text1.1',
        element sth {},
        'text1.2'
      },
      element entry {
        attribute myId { 'id2' },
        'text2'
      }
    }
  })
};
