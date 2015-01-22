module namespace reportTest = 'reportTest';

import module namespace report = 'report';

declare variable $reportTest:TEST-DOC := document {
  element items {
    element entry {
      attribute myId { 'id1' },
      'text1  '
    },
    element entry {
      attribute myId { 'id2' },
      'text2'
    }
  }
};

declare variable $reportTest:SETUP := map {
  'item-selector': function($rootContext as item()) as element(entry)* {
    $rootContext//entry
  },
  'id-selector': function($item as element()) {
    $item/@myId/fn:string()
  },
  'test': ('normalize ws', function($entry as element()) {
    let $t := $entry/text()
    where fn:normalize-space($t) ne $t
    return $t
  }),
  'fix': function($entry as element(), $cache as map(*)) {
    let $t := $entry/text()
    where fn:normalize-space($t) ne $t
    return fn:normalize-space($t)
  },
  'cache': map {
  }
};

declare %unit:test function reportTest:as-xml()
{
  let $report := report:as-xml($reportTest:TEST-DOC, $reportTest:SETUP)
  let $cleaned := report:apply-to-document($report, $reportTest:TEST-DOC, $reportTest:SETUP)
  return unit:assert-equals($cleaned, document {
    element items {
      element entry {
        attribute myId { 'id1' },
        'text1'
      },
      element entry {
        attribute myId { 'id2' },
        'text2'
      }
    }
  })
};
