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

declare %unit:test function reportTest:as-xml()
{
  let $report := report:as-xml($reportTest:TEST-DOC)
  let $cleaned := report:apply-to-document($report, $reportTest:TEST-DOC)
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
