import '../../domain/crm_models.dart';

bool isExcelLead(CrmLead l) =>
    !l.isManual &&
    (l.leadSource == 'EXCEL' || l.customFields['isExcelImport'] == true);

bool isAdsLead(CrmLead l) =>
    !l.isManual &&
    (l.leadSource == 'WEBHOOK' ||
        l.leadSource == 'META' ||
        l.leadSource == 'GOOGLE');

/// Campaigns a user may pick for a given lead-flow chip.
List<CrmCampaign> campaignsForLeadFlow({
  required String flow,
  required List<CrmCampaign> campaigns,
  required List<CrmLead> leads,
  required bool isAdmin,
  int? userEmployeeId,
  required bool isExcelAssigned,
  required bool isMetaAssigned,
  required bool isGoogleAssigned,
}) {
  if (flow == 'ALL') return const [];

  bool canAccess(CrmCampaign c) {
    if (isAdmin) return true;
    final assigned = userEmployeeId != null &&
        c.assignedTelecallerIds.contains(userEmployeeId);
    if (assigned) return true;
    if (flow == 'EXCEL' && isExcelAssigned) return true;
    if (flow == 'MANUAL' && isExcelAssigned) return true;
    if (flow == 'WEBHOOK') {
      final p = c.platform.toUpperCase();
      if (isMetaAssigned && (p == 'META' || p == 'WEBHOOK')) return true;
      if (isGoogleAssigned && p == 'GOOGLE') return true;
      // Both ads desks: any ads platform campaign
      if ((isMetaAssigned || isGoogleAssigned) &&
          (p == 'META' || p == 'GOOGLE' || p == 'WEBHOOK')) {
        return true;
      }
    }
    return false;
  }

  bool matchesFlow(CrmCampaign c) {
    switch (flow) {
      case 'EXCEL':
        return leads.any((l) => l.campaignId == c.id && isExcelLead(l));
      case 'MANUAL':
        return leads.any((l) => l.campaignId == c.id && l.isManual) ||
            c.code.toUpperCase().contains('DEFAULT') ||
            c.name.toUpperCase().contains('DEFAULT');
      case 'WEBHOOK':
        final p = c.platform.toUpperCase();
        if (!(p == 'META' || p == 'GOOGLE' || p == 'WEBHOOK')) return false;
        if (isAdmin || (!isMetaAssigned && !isGoogleAssigned)) return true;
        if (isMetaAssigned && isGoogleAssigned) return true;
        if (isMetaAssigned) return p == 'META' || p == 'WEBHOOK';
        if (isGoogleAssigned) return p == 'GOOGLE';
        return true;
      default:
        return true;
    }
  }

  final matched = campaigns.where((c) => canAccess(c) && matchesFlow(c)).toList();

  // Fallback: if no lead-matched campaigns, still offer accessible campaigns
  // of the right platform (new empty campaigns / fresh imports).
  if (matched.isEmpty) {
    return campaigns.where((c) {
      if (!canAccess(c)) return false;
      if (flow == 'WEBHOOK') {
        final p = c.platform.toUpperCase();
        return p == 'META' || p == 'GOOGLE' || p == 'WEBHOOK';
      }
      // Excel/Manual: any accessible campaign is a valid import/manual target
      return flow == 'EXCEL' || flow == 'MANUAL';
    }).toList();
  }
  return matched;
}

int leadCountForCampaignFlow({
  required CrmCampaign campaign,
  required String flow,
  required List<CrmLead> leads,
}) {
  return leads.where((l) {
    if (l.campaignId != campaign.id) return false;
    switch (flow) {
      case 'EXCEL':
        return isExcelLead(l);
      case 'MANUAL':
        return l.isManual;
      case 'WEBHOOK':
        return isAdsLead(l);
      default:
        return true;
    }
  }).length;
}
