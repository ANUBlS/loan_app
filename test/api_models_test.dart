import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loan_app/data/api_client.dart';
import 'package:loan_app/data/mock_data.dart';
import 'package:loan_app/models/loan.dart';

// Real responses of the Loan API (github.com/ANUBlS/loan_api), shortened.
Map<String, dynamic> _json(String s) => jsonDecode(s) as Map<String, dynamic>;

const _loan = r'''
{
  "id": "1afd9a7d-d844-4cb6-8afb-4b22fe02f733",
  "type": "car",
  "productName": "product.car_loan",
  "contractNo": "AU-2026-000932",
  "currency": "AZN",
  "amount": 25000.0,
  "annualRate": 14.0,
  "termMonths": 48,
  "startDate": "2026-01-24",
  "schedule": [
    {
      "number": 6,
      "dueDate": "2026-07-24",
      "principal": 414.87,
      "interest": 268.29,
      "total": 683.16,
      "balanceAfter": 22581.45,
      "paidDate": "2026-07-24T12:00:00+04:00",
      "status": "paid"
    },
    {
      "number": 7,
      "dueDate": "2026-08-24",
      "principal": 419.71,
      "interest": 263.45,
      "total": 683.16,
      "balanceAfter": 22161.74,
      "paidDate": "2026-10-03T15:36:56.681740+04:00",
      "status": "paid"
    },
    {
      "number": 8,
      "dueDate": "2026-09-24",
      "principal": 424.61,
      "interest": 258.55,
      "total": 683.16,
      "balanceAfter": 21737.13,
      "paidDate": null,
      "status": "overdue"
    }
  ]
}
''';

const _product = r'''
{
  "id": 2,
  "code": "car",
  "type": "car",
  "name": "product.car",
  "loanName": "product.car_loan",
  "annualRate": 13.5,
  "minAmount": 5000.0,
  "maxAmount": 80000.0,
  "step": 500.0,
  "minTerm": 12,
  "maxTerm": 84
}
''';

const _application = r'''
{
  "id": "1132ec9a-1af9-4515-ab19-61e5d465fd0e",
  "reference": "APP-000002",
  "type": "car",
  "productName": "product.car_loan",
  "amount": 5500.0,
  "termMonths": 12,
  "annualRate": 13.5,
  "monthlyPayment": 492.54,
  "purpose": "purpose.car",
  "currency": "AZN",
  "status": "submitted",
  "decisionNote": null,
  "createdAt": "2026-10-03T15:36:56.667840+04:00",
  "decidedAt": null,
  "loanId": null
}
''';

const _document = r'''
{
  "id": "8ae41e3d-046f-43cd-946c-4f0e62075cfe",
  "name": "doc.agreement",
  "fileName": "AU-2026-000932-agreement.pdf",
  "contentType": "application/pdf",
  "sizeKb": 1,
  "createdAt": "2026-10-03T15:36:23.914188+04:00",
  "downloadUrl": "/api/v1/documents/8ae41e3d-046f-43cd-946c-4f0e62075cfe/download"
}
''';

void main() {
  test('loan with schedule parses from GET /loans/{id}', () {
    final loan = Loan.fromJson(_json(_loan));
    expect(loan.type, LoanType.car);
    expect(loan.productName, 'product.car_loan');
    expect(loan.contractNo, 'AU-2026-000932');
    expect(loan.amount, 25000);
    expect(loan.schedule, hasLength(3));
    expect(loan.schedule[0].number, 6);
    expect(loan.schedule[0].isPaid, isTrue);
    expect(loan.schedule[2].isPaid, isFalse);
    expect(loan.schedule[2].dueDate, DateTime(2026, 9, 24));
    expect(loan.schedule[2].total, closeTo(683.16, 0.001));
    expect(loan.paidCount, 2);
  });

  test('product, application and document parse', () {
    final p = LoanProduct.fromJson(_json(_product));
    expect(p.id, 2);
    expect(p.type, LoanType.car);
    expect(p.loanName, 'product.car_loan');
    expect(p.amountDivisions, 150);

    final a = LoanApplication.fromJson(_json(_application));
    expect(a.reference, 'APP-000002');
    expect(a.status, 'submitted');
    expect(a.monthlyPayment, closeTo(492.54, 0.001));

    final d = LoanDocument.fromJson(_json(_document));
    expect(d.nameKey, 'doc.agreement');
    expect(d.downloadUrl, startsWith('/api/v1/documents/'));
  });

  test('server address is normalized', () {
    expect(ApiClient.normalizeUrl(' 192.168.1.10:8000/ '), 'http://192.168.1.10:8000');
    expect(ApiClient.normalizeUrl('https://api.example.az'), 'https://api.example.az');
  });
}
