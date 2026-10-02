import 'package:intl/intl.dart';
import '../../domain/crm_models.dart';
import 'proposal_print_io.dart'
    if (dart.library.html) 'proposal_print_web.dart' as impl;

void printProposalQuotation({
  required CrmProposal proposal,
  void Function(String message)? onMessage,
}) {
  final currencyFormat = NumberFormat("#,##,###", "en_IN");
  final dateFormat = DateFormat("dd MMMM yyyy");

  final dateFormatted = dateFormat.format(proposal.createdAt);
  final expiryFormatted = dateFormat.format(proposal.expiryDate);

  final rowsBuffer = StringBuffer();

  // 1. Base Price
  rowsBuffer.write('''
    <tr>
      <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
        <strong>Base Price (BSV)</strong>
        <div style="font-size: 11px; color: #64748b;">Super Built-Up Area: ${proposal.superBuiltUp.toStringAsFixed(0)} sq.ft @ ₹ ${proposal.baseRate.toStringAsFixed(0)} / sq.ft</div>
      </td>
      <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">
        ${proposal.superBuiltUp.toStringAsFixed(0)} sq.ft × ₹ ${proposal.baseRate.toStringAsFixed(0)}
      </td>
      <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
        ₹ ${currencyFormat.format(proposal.basePrice)}
      </td>
    </tr>
  ''');

  // 2. PLC
  if (proposal.plc > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Preferential Location Charge (PLC)</strong>
          <div style="font-size: 11px; color: #64748b;">Prime facing / road / park view premium</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">Configured Rate</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.plc)}
        </td>
      </tr>
    ''');
  }

  // 3. FRC
  if (proposal.frc > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Floor Rise Charge (FRC)</strong>
          <div style="font-size: 11px; color: #64748b;">Floor ${proposal.floorNo} floor premium</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">Floor Rise</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.frc)}
        </td>
      </tr>
    ''');
  }

  // 4. Development Charges
  if (proposal.developmentCharges > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Development & Infrastructure Charges</strong>
          <div style="font-size: 11px; color: #64748b;">GEB / AMC / Electrification / Club amenities</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">Development</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.developmentCharges)}
        </td>
      </tr>
    ''');
  }

  // 5. GST
  if (proposal.gstAmount > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Goods & Services Tax (GST)</strong>
          <div style="font-size: 11px; color: #64748b;">Government statutory tax (${proposal.gstPercentage.toStringAsFixed(0)}%)</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">${proposal.gstPercentage.toStringAsFixed(0)}%</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.gstAmount)}
        </td>
      </tr>
    ''');
  }

  // 6. Stamp Duty
  if (proposal.stampDutyAmount > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Stamp Duty Charges</strong>
          <div style="font-size: 11px; color: #64748b;">State government registration requirement (${proposal.stampDutyPercentage.toStringAsFixed(1)}%)</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">${proposal.stampDutyPercentage.toStringAsFixed(1)}%</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.stampDutyAmount)}
        </td>
      </tr>
    ''');
  }

  // 7. Registration Charges
  if (proposal.registrationCharges > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Registration Fees</strong>
          <div style="font-size: 11px; color: #64748b;">Sub-registrar office statutory fee</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">Statutory</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.registrationCharges)}
        </td>
      </tr>
    ''');
  }

  // 8. Maintenance
  if (proposal.maintenanceCharges > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Maintenance Advance & Deposit</strong>
          <div style="font-size: 11px; color: #64748b;">Society maintenance & sinking fund provision</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">Advance / Deposit</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.maintenanceCharges)}
        </td>
      </tr>
    ''');
  }

  // 9. Other / Legal Charges
  if (proposal.otherChargesAmount > 0) {
    rowsBuffer.write('''
      <tr>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0;">
          <strong>Legal & Documentation Charges</strong>
          <div style="font-size: 11px; color: #64748b;">Advocate documentation & agreement execution</div>
        </td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: center; color: #475569;">Documentation</td>
        <td style="padding: 9px 12px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 600;">
          ₹ ${currencyFormat.format(proposal.otherChargesAmount)}
        </td>
      </tr>
    ''');
  }

  final html = '''
    <!-- Header Letterhead -->
    <div style="display: flex; justify-content: space-between; align-items: flex-start; padding-bottom: 16px; border-bottom: 2px solid #0f172a;">
      <div>
        <div style="font-size: 24px; font-weight: 800; color: #0f172a; letter-spacing: 0.5px;">NB DEVELOPERS</div>
        <div style="font-size: 13px; font-weight: 600; color: #b45309; text-transform: uppercase; margin-top: 2px;">Official Property Price Quotation</div>
        <div style="font-size: 11px; color: #64748b; margin-top: 3px;">Real Estate & Infrastructure Development</div>
      </div>
      <div style="text-align: right; font-size: 11.5px; color: #334155;">
        <div><strong>Proposal Ref:</strong> <span style="font-family: monospace;">#${proposal.id}</span> (Rev ${proposal.revision})</div>
        <div style="margin-top: 3px;"><strong>Date:</strong> $dateFormatted</div>
        <div style="margin-top: 3px; color: #b45309; font-weight: 700;"><strong>Valid Until:</strong> $expiryFormatted</div>
        <div style="margin-top: 3px; font-size: 11px; color: #64748b;">By: ${proposal.createdByName ?? 'Sales Executive'}</div>
      </div>
    </div>

    <!-- Client & Property Details Grid -->
    <div style="display: flex; gap: 20px; margin-top: 18px;">
      <!-- Client Details Box -->
      <div style="flex: 1; border: 1px solid #cbd5e1; border-radius: 6px; padding: 12px 14px; background: #f8fafc;">
        <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: #0f172a; border-bottom: 1px solid #cbd5e1; padding-bottom: 4px; margin-bottom: 8px;">
          Client Information
        </div>
        <table style="width: 100%; font-size: 11.5px; border-collapse: collapse;">
          <tr>
            <td style="color: #64748b; width: 85px; padding: 2px 0;">Name:</td>
            <td style="font-weight: 700; color: #0f172a;">${proposal.clientName}</td>
          </tr>
          <tr>
            <td style="color: #64748b; padding: 2px 0;">Mobile:</td>
            <td style="font-weight: 600;">${proposal.clientPhone}</td>
          </tr>
          ${proposal.clientEmail.isNotEmpty ? '<tr><td style="color: #64748b; padding: 2px 0;">Email:</td><td>${proposal.clientEmail}</td></tr>' : ''}
          ${proposal.clientAddress.isNotEmpty ? '<tr><td style="color: #64748b; padding: 2px 0;">Address:</td><td>${proposal.clientAddress}</td></tr>' : ''}
        </table>
      </div>

      <!-- Property Details Box -->
      <div style="flex: 1; border: 1px solid #cbd5e1; border-radius: 6px; padding: 12px 14px; background: #f8fafc;">
        <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: #0f172a; border-bottom: 1px solid #cbd5e1; padding-bottom: 4px; margin-bottom: 8px;">
          Unit & Property Specifications
        </div>
        <table style="width: 100%; font-size: 11.5px; border-collapse: collapse;">
          <tr>
            <td style="color: #64748b; width: 110px; padding: 2px 0;">Project:</td>
            <td style="font-weight: 700; color: #0f172a;">${proposal.projectName}</td>
          </tr>
          <tr>
            <td style="color: #64748b; padding: 2px 0;">Tower / Unit:</td>
            <td style="font-weight: 700;">${proposal.towerName} • Unit #${proposal.unitNo}</td>
          </tr>
          <tr>
            <td style="color: #64748b; padding: 2px 0;">Type & Floor:</td>
            <td style="font-weight: 600;">${proposal.unitType} (Floor ${proposal.floorNo})</td>
          </tr>
          <tr>
            <td style="color: #64748b; padding: 2px 0;">Area Specs:</td>
            <td>Carpet: <strong>${proposal.carpetArea.toStringAsFixed(0)}</strong> sq.ft | Super Built-up: <strong>${proposal.superBuiltUp.toStringAsFixed(0)}</strong> sq.ft</td>
          </tr>
        </table>
      </div>
    </div>

    <!-- Financial Breakdown Table -->
    <div style="margin-top: 20px;">
      <div style="font-size: 12px; font-weight: 800; text-transform: uppercase; color: #0f172a; margin-bottom: 8px; letter-spacing: 0.3px;">
        Itemized Financial Breakdown & Pricing
      </div>
      <table style="width: 100%; border-collapse: collapse; border: 1px solid #cbd5e1; font-size: 12px;">
        <thead>
          <tr style="background: #0f172a; color: #ffffff;">
            <th style="padding: 10px 12px; text-align: left; font-weight: 700; width: 52%;">Component Description</th>
            <th style="padding: 10px 12px; text-align: center; font-weight: 700; width: 23%;">Basis / Formula</th>
            <th style="padding: 10px 12px; text-align: right; font-weight: 700; width: 25%;">Amount (INR)</th>
          </tr>
        </thead>
        <tbody>
          ${rowsBuffer.toString()}
          <!-- Net Grand Total Row -->
          <tr style="background: #ecfdf5; border-top: 2px solid #059669; border-bottom: 2px solid #059669;">
            <td style="padding: 12px 14px;" colspan="2">
              <span style="font-size: 13px; font-weight: 800; color: #065f46; text-transform: uppercase; letter-spacing: 0.3px;">
                Net Total Unit Value / Payable
              </span>
              <div style="font-size: 10.5px; color: #047857; margin-top: 2px;">
                Inclusive of basic value, applicable statutory taxes, advance maintenance, and development charges.
              </div>
            </td>
            <td style="padding: 12px 14px; text-align: right; font-size: 17px; font-weight: 800; color: #047857;">
              ₹ ${currencyFormat.format(proposal.grandTotal)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Description (if any) -->
    ${proposal.description.isNotEmpty ? '''
      <div style="margin-top: 16px; border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px 12px; background: #ffffff;">
        <div style="font-weight: 700; font-size: 11px; text-transform: uppercase; color: #475569; margin-bottom: 4px;">Unit Remarks & Notes</div>
        <div style="font-size: 11.5px; color: #1e293b;">${proposal.description}</div>
      </div>
    ''' : ''}

    <!-- Disclaimer & Standard Terms -->
    ${proposal.disclaimer.isNotEmpty ? '''
      <div style="margin-top: 14px; padding: 10px 12px; background: #f8fafc; border-left: 3px solid #b45309; border-radius: 0 4px 4px 0; font-size: 10.5px; color: #475569; line-height: 1.5;">
        <div style="font-weight: 700; color: #92400e; margin-bottom: 3px; text-transform: uppercase; font-size: 10.5px;">Terms & Conditions:</div>
        <div>${proposal.disclaimer.replaceAll('\n', '<br/>')}</div>
      </div>
    ''' : ''}

    <!-- Validity Notice -->
    <div style="margin-top: 14px; padding: 8px 12px; background: #fef3c7; border: 1px solid #fde68a; border-radius: 6px; font-size: 11px; color: #92400e; text-align: center; font-weight: 600;">
      ⚠️ This proposal is valid till <strong>$expiryFormatted</strong>. Booking is subject to clearance of booking token and standard terms of agreement.
    </div>

    <!-- Formal Signatures & Acknowledgement Block -->
    <div style="display: flex; justify-content: space-between; margin-top: 36px; padding-top: 14px; page-break-inside: avoid;">
      <div style="width: 220px; text-align: center;">
        <div style="border-top: 1px solid #0f172a; padding-top: 6px;">
          <div style="font-weight: 700; font-size: 11.5px; color: #0f172a;">${proposal.createdByName ?? 'Sales Executive'}</div>
          <div style="font-size: 10px; color: #64748b;">Authorized Sales Consultant</div>
          <div style="font-size: 10px; color: #64748b; margin-top: 2px;">NB Developers</div>
        </div>
      </div>

      <div style="width: 220px; text-align: center;">
        <div style="border-top: 1px solid #0f172a; padding-top: 6px;">
          <div style="font-weight: 700; font-size: 11.5px; color: #0f172a;">${proposal.clientName}</div>
          <div style="font-size: 10px; color: #64748b;">Client Acceptance Signature</div>
          <div style="font-size: 10px; color: #64748b; margin-top: 2px;">Date: _______________</div>
        </div>
      </div>
    </div>
  ''';

  impl.printQuotationWeb(
    title: 'Quotation_${proposal.unitNo}_${proposal.clientName}',
    htmlContent: html,
    onMessage: onMessage,
  );
}
