import '../models/tour_models.dart';

/// In-depth spoken scripts. Each step navigates to the real screen.
class TourScripts {
  TourScripts._();

  static TourStep step({
    required String sectionId,
    required int order,
    required String title,
    required String body,
    required String route,
    String clip = 'pointing',
    String? targetId,
  }) {
    return TourStep(
      id: '$sectionId.$order',
      sectionId: sectionId,
      title: title,
      description: body,
      order: order,
      route: route,
      targetId: targetId ?? TourIds.step(sectionId, order),
      mascotClip: clip,
      type: TourStepType.information,
      useMascot: true,
    );
  }

  static List<TourStep> hrmsHome() => [
        step(
          sectionId: 'hrms.home',
          order: 2,
          title: 'Punch and My Space',
          route: '/home',
          body:
              'At the top you see today’s punch in and punch out. Punch in now jumps to Attendance. Search filters these cards. Upcoming birthdays remind you about colleagues. My Space holds Profile, Leave, Attendance, Reimbursements, Recruitment, Repository, Tasks, Chat and Meet, but only the cards your role may open.',
        ),
        step(
          sectionId: 'hrms.home',
          order: 3,
          title: 'Management and System Administration',
          route: '/home',
          clip: 'thinking',
          body:
              'Management and Approvals is for people who review others: Workforce, Profile Approvals, Leave Approvals, Payroll. System Administration is Users, Roles, Configurations, Storage and Audit. If a whole group is missing, you are not an admin. Never ask a colleague to share their login to see hidden cards. Request a role change instead.',
        ),
      ];

  static List<TourStep> profile() => [
        step(
          sectionId: 'hrms.profile',
          order: 2,
          title: 'Profile tabs',
          route: '/profile',
          body:
              'Tabs are General, Personal, Address, Other, Family, Academic, Experience, Documents, Bank, Salary and Attendance. General is job and institute. Personal is identity details. Bank and Salary feed payroll, so mistakes delay slips. Documents hold letters and uploads. Attendance tab is your own punch history, not the live Punch button.',
        ),
        step(
          sectionId: 'hrms.profile',
          order: 3,
          title: 'Edit Profile and approvals',
          route: '/profile',
          clip: 'thinking',
          body:
              'Edit Profile opens a form. Sensitive changes often go to Profile Approvals for HR. After you submit, wait for Approved before you assume payroll or letters already use the new data. Open a salary slip from the Salary tab when a month is published. Do not edit another employee’s profile from here. That is Workforce.',
        ),
      ];

  static List<TourStep> leave() => [
        step(
          sectionId: 'hrms.leave',
          order: 2,
          title: 'Balances and year',
          route: '/leave',
          body:
              'This is Leave Management. Pick the year first. Leave Balances Overview shows remaining days by type. Types marked Admin cannot be self-applied. Recent Applications is your latest requests. Refresh reloads balances after an approval. Apply Leave and History are the two buttons you will use every cycle.',
        ),
        step(
          sectionId: 'hrms.leave',
          order: 3,
          title: 'How to apply leave',
          route: '/leave/apply',
          body:
              'Apply Leave needs type, from date, to date, and a reason of at least five characters. Half day needs Morning or Afternoon. Some types require a supporting PDF or image. Upload, Replace or Remove the file before Submit. Overlapping dates, exhausted balance, or a holiday-only range will be rejected. Submit once. Then watch History.',
        ),
        step(
          sectionId: 'hrms.leave',
          order: 4,
          title: 'History and cancel',
          route: '/leave/history',
          clip: 'thinking',
          body:
              'History filters All, Pending, Approved, Rejected and Cancelled, plus year. Open a pending row to Cancel Request if plans change. You cannot cancel after it is approved unless policy allows. Rejected rows show remarks. Use this before you argue with payroll about an absent day.',
        ),
        step(
          sectionId: 'hrms.leave',
          order: 5,
          title: 'Approvals',
          route: '/approvals',
          body:
              'If you approve others, Leave Approvals is the queue. Open a request, read dates and reason, then Approve or Reject with remarks. History under Approvals is what you already decided. Do not leave pending items sitting. People plan travel on your decision.',
        ),
        step(
          sectionId: 'hrms.leave',
          order: 6,
          title: 'Leave admin, holidays and apply on behalf',
          route: '/admin/leaves',
          clip: 'thinking',
          body:
              'Leave Admin is for HR. Approvals, Settings, Holidays and Apply on behalf live here. Settings define leave types and whether employees can apply. Holidays block those dates. Apply on behalf files leave for someone who cannot use the app. Pending under admin is the company-wide pile, not only your reportees.',
        ),
      ];

  static List<TourStep> attendance() => [
        step(
          sectionId: 'hrms.attendance',
          order: 2,
          title: 'Punch rules',
          route: '/attendance',
          body:
              'Punch is only for today, Indian Standard Time. Maximum two punches a day, with at least a twenty minute gap. You must be inside the geofence if the organisation enabled locations. First time, register fingerprint, Face ID, or Safari on iPhone web. Punch In starts the day. Punch Out asks for confirm. The calendar shows the month. Tap a day for punches and the map.',
        ),
        step(
          sectionId: 'hrms.attendance',
          order: 3,
          title: 'Admin attendance',
          route: '/admin/attendance',
          clip: 'thinking',
          body:
              'Manage Attendance is HR. You can add a missed punch, open device attendance, and maintain locations used by geofence. Open an employee to see their month. Do not invent punches without a reason. Locations must match real sites or field staff will fail to punch.',
        ),
      ];

  static List<TourStep> reimbursements() => [
        step(
          sectionId: 'hrms.reimbursements',
          order: 2,
          title: 'My claims and apply',
          route: '/reimbursements',
          body:
              'The hub shows claims waiting for your approval, then My claims. Apply opens a form: title is required, then description, amount, and optional opening and closing kilometres for travel. Upload proof. Submit once. Track pending versus paid here. Rejected claims include remarks. Fix and apply again if needed.',
        ),
        step(
          sectionId: 'hrms.reimbursements',
          order: 3,
          title: 'Approve claims',
          route: '/reimbursements',
          clip: 'thinking',
          body:
              'Approvers see Pending for your approval. Approve or Reject with optional remarks. Admin, all claims, is the finance view. Unclear receipts delay payment. Do not approve your own claim. Opening and closing kilometres should match the trip.',
        ),
      ];

  static List<TourStep> recruitment() => [
        step(
          sectionId: 'hrms.recruitment',
          order: 2,
          title: 'Vacancies and interviews',
          route: '/recruitment',
          body:
              'Tabs are Vacancies and My interviews. With write access you also get Requirements and Candidates. A vacancy shows institute, locations, headcount, employment type, C T C, education, experience and skills. Open a vacancy for the full sheet. My interviews is the schedule assigned to you.',
        ),
        step(
          sectionId: 'hrms.recruitment',
          order: 3,
          title: 'Requirements and candidates',
          route: '/recruitment',
          clip: 'thinking',
          body:
              'Add requirement creates an opening. Add candidate files a person against the pipeline. Open a candidate for resume, notes, stage and interviews. Move stages only if you have write access. Keep offer letters on the candidate record, not only in chat.',
        ),
      ];

  static List<TourStep> repository() => [
        step(
          sectionId: 'hrms.repository',
          order: 2,
          title: 'Categories and upload',
          route: '/repository',
          body:
              'Documents sit in Policy, Handbook, Form and Other. Open or download to read. Managers get Upload. Choose the category, pick a file, then save. Remove only if you may manage the repository. Put company-wide files here, not in a private chat, so new joiners still find them next year.',
        ),
      ];

  static List<TourStep> payroll() => [
        step(
          sectionId: 'hrms.payroll',
          order: 2,
          title: 'Month KPIs and mark paid',
          route: '/admin/salary/payroll',
          body:
              'Pick year and month. KPIs are employees, calculated, not calculated, unpaid, paid, paid amount, remaining and total net. Open an employee to Mark paid or Mark unpaid. Open profile salary to inspect the slip. Run calculations before you mark paid. Header links go to Entry, Structures and Records.',
        ),
        step(
          sectionId: 'hrms.payroll',
          order: 3,
          title: 'Structures, entry and records',
          route: '/admin/salary/structures',
          clip: 'thinking',
          body:
              'Structures are the templates: earnings and deductions. Entry is the month’s input. Records is history. Fix bank and tax on the employee before you calculate. After you publish, staff download slips from Profile, Salary. Commissions are a separate screen when your organisation uses them.',
        ),
      ];

  static List<TourStep> workforce() => [
        step(
          sectionId: 'hrms.workforce',
          order: 2,
          title: 'Directory and add employee',
          route: '/admin/employees',
          body:
              'Search by name, code or id. Add Employee needs Organisation, Institute, Designation, engagement category and date of birth, plus role. Those fields drive leave, org tree and letters. Open a row for the full record. Terminate or activate instead of deleting history. Keep the reporting manager correct or the employee tree breaks.',
        ),
      ];

  static List<TourStep> users() => [
        step(
          sectionId: 'hrms.users',
          order: 2,
          title: 'Accounts, credentials and unlock',
          route: '/admin/users',
          body:
              'Add a user only after the employee exists. Assign a role. Filter by status and role. Credentials shows how they log in. Edit changes role or mapping. Delete is rare. Unlock clears a lockout. Disable leavers. Never share one admin user. First login is usually employee id and date of birth until they change the password.',
        ),
      ];

  static List<TourStep> roles() => [
        step(
          sectionId: 'hrms.roles',
          order: 2,
          title: 'Permission matrix',
          route: '/admin/roles',
          body:
              'Open a role. Columns are Read or View, Create or Edit, Approve, Delete and Export, per module. Grant All, Read Only or Revoke All are bulk tools. This tour hides screens the role does not grant. Too much access exposes payroll and CRM. Too little blocks daily work. Test with one user after you change a role.',
        ),
      ];

  static List<TourStep> configurations() => [
        step(
          sectionId: 'hrms.configurations',
          order: 2,
          title: 'Masters: orgs, institutes, designations',
          route: '/admin/configurations',
          body:
              'Tiles include Organisations, Institutes, Designations, Letters and Storage, plus lookup categories such as interview types. Create organisation and institute before employees. Designations appear on Workforce and letters. Letters are templates. Storage is file quotas. Change a designation name carefully. Old employee rows still point at the id.',
        ),
      ];

  static List<TourStep> storage() => [
        step(
          sectionId: 'hrms.storage',
          order: 2,
          title: 'Quotas and sources',
          route: '/admin/storage',
          body:
              'The usage bar is organisation-wide. Breakdown covers profile photos, letters, reimbursements, chat and Cloudinary when connected. If Cloudinary is off, only in-app collaboration files show. Clearing space is an admin job. Staff should still prefer Repository for policies everyone must keep.',
        ),
      ];

  static List<TourStep> audit() => [
        step(
          sectionId: 'hrms.audit',
          order: 2,
          title: 'Filters and what is logged',
          route: '/admin/audit',
          body:
              'Filter by user, action and date. Typical rows are login, role change, employee update and payroll publish. Open a row for before-and-after when the logger stored it. Use this after a dispute, not as a daily inbox. You cannot edit history here.',
        ),
      ];

  static List<TourStep> dashboard() => [
        step(
          sectionId: 'hrms.dashboard',
          order: 2,
          title: 'KPIs and charts',
          route: '/admin/dashboard',
          body:
              'Refresh reloads live counts. Total employees, active staff, departments and pending tasks sit on top. Department Allocation is the donut. Workforce Growth Trend is the year line. Category split shows engagement mix. Use this in the morning, then drill into Leave, Tasks or Tracking. It does not replace module screens.',
        ),
      ];

  static List<TourStep> earth() => [
        step(
          sectionId: 'hrms.earth',
          order: 2,
          title: 'Globe, map and properties',
          route: '/admin/earth',
          body:
              'Switch Globe and Map. Map tools are Browse, Pin, Distance and Area. Layers include satellite. Search geocodes an address. Add property drops a site. Filters are type and status. Spin, day or night, and zoom are view only. Open a property sheet to edit or remove. This is the company map, not live staff GPS.',
        ),
      ];

  static List<TourStep> earthDashboard() => [
        step(
          sectionId: 'hrms.earth_dashboard',
          order: 2,
          title: 'City and property metrics',
          route: '/admin/earth/dashboard',
          body:
              'Earth Dashboard aggregates cities and properties: counts and prices. Use it for a briefing. For drawing and pins, go back to NB Earth. For people moving, go to Live Tracking.',
        ),
      ];

  static List<TourStep> liveTracking() => [
        step(
          sectionId: 'hrms.live_tracking',
          order: 2,
          title: 'Live map and duty',
          route: '/admin/live-tracking',
          body:
              'The map shows who is live. Duty availability is on the side. Geofence picker limits the view. Tap an employee for last point, speed and trail, or open their full live page. Location alerts can sound when someone leaves a fence. Use this during work hours. History is Trips.',
        ),
      ];

  static List<TourStep> trips() => [
        step(
          sectionId: 'hrms.trips',
          order: 2,
          title: 'Replay and download',
          route: '/admin/trips',
          body:
              'Browse recorded trips. Open a trip to replay the path. Download trip video when the organisation enabled recording. Use trips for mileage, site visits and exceptions. Live Tracking is now. Trips is the archive.',
        ),
      ];

  static List<TourStep> trackingHub() => [
        step(
          sectionId: 'hrms.tracking',
          order: 2,
          title: 'Field Intelligence',
          route: '/admin/tracking-hub',
          body:
              'Tracking Hub is Field Intelligence. Pick a date, employee and status. KPIs, day availability and the trip list sit together. It auto-refreshes about every five seconds. Download trip video from a row. Open an employee or trip for detail. The sidebar badge follows alerts into this hub.',
        ),
      ];

  static List<TourStep> approvals() => [
        step(
          sectionId: 'hrms.approvals',
          order: 2,
          title: 'Filter and decide',
          route: '/admin/approvals',
          body:
              'Filters are Pending, Approved, Rejected and All. Open a request, compare the old and new values, then Approve or Reject. Pending changes can block payroll and letters. Do not rubber-stamp bank account edits.',
        ),
      ];

  static List<TourStep> erpHome() => [
        step(
          sectionId: 'erp.home',
          order: 2,
          title: 'Projects, resources, tenders, progress',
          route: '/erp/home',
          body:
              'Tiles are grouped: Projects, Work Orders and Resources, Tenders, and Progress. Typical flow: create a Project, add towers and units, issue Work Orders, maintain B O Q, receive materials in Store, file Tenders, then submit D P R each day. Configurations holds activities, contractors and lookups the forms need. Missing tiles mean missing permission.',
        ),
      ];

  static List<TourStep> projects() => [
        step(
          sectionId: 'erp.projects',
          order: 2,
          title: 'Add project and structure',
          route: '/erp/projects',
          body:
              'Add Project with name, location and codes. Open a project to Edit or Delete. Manage Structure is towers and units. Add Tower, then units under the tower. Unit status, available, sold or blocked, is shared with CRM post-sales. Create the project before work orders or B O Q. Do not duplicate the same site twice.',
        ),
      ];

  static List<TourStep> workOrders() => [
        step(
          sectionId: 'erp.work_orders',
          order: 2,
          title: 'Issue and track',
          route: '/erp/work-orders',
          body:
              'Add Work Order against a project, with scope, dates and contractor. Open a row for detail and Edit. Track issue, progress and close. Link the correct project so B O Q and D P R line up. Office follow-ups belong in Tasks, not as a second work order.',
        ),
      ];

  static List<TourStep> boq() => [
        step(
          sectionId: 'erp.boq',
          order: 2,
          title: 'Quantities, activities, labour',
          route: '/erp/boq',
          body:
              'New B O Q starts a bill of quantities. Expand a task for activities, materials, machines and labour. Keep quantities honest with site. Store issues and D P R should reconcile against this list. Lock a version when a tender or contract uses it. Edit opens the form for that B O Q.',
        ),
      ];

  static List<TourStep> store() => [
        step(
          sectionId: 'erp.store',
          order: 2,
          title: 'Material inward and outward',
          route: '/erp/store',
          body:
              'Top tabs are Material and Machine. Material splits Inward and Outward. Save Material records a receipt. Dispatch Outward issues to a project. Wrong unit of measure or project corrupts consumption. Configure item masters in ERP Configurations if the list is empty.',
        ),
        step(
          sectionId: 'erp.store',
          order: 3,
          title: 'Machines, issues and returns',
          route: '/erp/store',
          clip: 'thinking',
          body:
              'Machine has Inward and Stock, and Issue and Returns. Save Machine, add stock as a purchase, then issue equipment and take returns. Treat returns as first-class. Lost assets stay on the last project until you return them.',
        ),
      ];

  static List<TourStep> tenders() => [
        step(
          sectionId: 'erp.tenders',
          order: 2,
          title: 'New tender',
          route: '/erp/tenders',
          body:
              'New Tender creates a bid package with dates and documents. Open a tender to edit. Keep closing dates honest. Applications are a separate screen. Awarding here without recording the application leaves a hole in the audit trail.',
        ),
      ];

  static List<TourStep> tenderApps() => [
        step(
          sectionId: 'erp.tender_applications',
          order: 2,
          title: 'New application and status',
          route: '/erp/tender-applications',
          body:
              'New Application files a bidder response. Open one for commercials and documents. Change Status for award or rejection. You need tender application permission even if you can already view tenders.',
        ),
      ];

  static List<TourStep> dpr() => [
        step(
          sectionId: 'erp.dpr',
          order: 2,
          title: 'Daily progress: tasks, material, labour, machines',
          route: '/erp/dpr',
          body:
              'New D P R is today’s site report. Add Task, Add Material, Add Labour, Add Machine. Submit for the correct project and date. Managers read this instead of WhatsApp. File the same day. Open a past D P R from the list. Late reports leave dashboards empty.',
        ),
      ];

  static List<TourStep> erpConfig() => [
        step(
          sectionId: 'erp.config',
          order: 2,
          title: 'Activities, contractors, labour, lookups',
          route: '/erp/configurations',
          body:
              'Search the config hub. Tiles include project lookups, Labour, Activities, Contractors, and work order or D P R masters. Set these before the first project. Activities and contractors appear on B O Q, work orders and D P R. Renaming a contractor later does not rewrite old orders.',
        ),
      ];

  static List<TourStep> crmDashboard() => [
        step(
          sectionId: 'crm.dashboard',
          order: 2,
          title: 'KPIs and follow-ups',
          route: '/crm/dashboard',
          body:
              'The banner welcomes you. KPI tiles are gated in Settings: active leads, today’s calls, interested deals, bin count, calls logged, answered, missed or busy, talk time, fresh leads and conversion. Today’s Scheduled Follow-ups is the call list. Mark Done when you finish. App bar has Bin, Settings and Refresh.',
        ),
        step(
          sectionId: 'crm.dashboard',
          order: 3,
          title: 'Modules',
          route: '/crm/dashboard',
          clip: 'thinking',
          body:
              'Tiles open Pre-sales, Post-sales, Bin and Settings. Pre-sales is demand. Post-sales is after booking. Bin is archive. Settings is organisation CRM config, including telephony, not your Profile.',
        ),
      ];

  static List<TourStep> preSales() => [
        step(
          sectionId: 'crm.pre_sales',
          order: 2,
          title: 'Leads, search and add',
          route: '/crm/pre-sales',
          body:
              'First tab is Leads and Inquiries. Search by name or phone. Add New Pre-Sales Lead starts a record. Click-to-Call uses Elision if Settings has the API. Edit the lead. Move to Bin archives it. Headers control which columns you see. Do not invent a side spreadsheet.',
        ),
        step(
          sectionId: 'crm.pre_sales',
          order: 3,
          title: 'Follow-ups, recordings, pipeline, quotations',
          route: '/crm/pre-sales',
          clip: 'thinking',
          body:
              'Follow-ups and Scheduled Calls is the cadence. Call Recordings holds audio. Pipeline and Deals is stage movement. Quotations is commercial paper. Log every follow-up on the lead. Merge columns only when Headers was designed for it.',
        ),
      ];

  static List<TourStep> headers() => [
        step(
          sectionId: 'crm.headers',
          order: 2,
          title: 'Projects, campaigns, webhooks',
          route: '/crm/pre-sales/headers',
          body:
              'Pick a project, then Campaigns and Headers. Add Project, Add Campaign, Add Table Header, or Merge Columns. Copy the webhook URL for Meta or Google style ingestion. Campaign ids must match the ad account. Adding a header changes every salesperson’s lead grid. Coordinate before you hide a column.',
        ),
      ];

  static List<TourStep> postSales() => [
        step(
          sectionId: 'crm.post_sales',
          order: 2,
          title: 'Handover, accounts, service, feedback',
          route: '/crm/post-sales',
          body:
              'Tabs are Handovers and Delivery, Customer Accounts, Service and Support, and Feedback and Reviews. New Ticket or Request opens service. Search accounts, units and projects. Keep the unit in sync with ERP Projects. Pre-sales is demand. Post-sales is delivery and care.',
        ),
      ];

  static List<TourStep> bin() => [
        step(
          sectionId: 'crm.bin',
          order: 2,
          title: 'Pre-sales and post-sales archive',
          route: '/crm/bin',
          body:
              'Tabs are Pre-sales Leads and Post-sales Archive. Discarded or not interested rows land here. Restore inside the retention window from Settings, often about thirty days. Deleting from bin is permanent if your role allows it. Prefer archive so the live grid stays clean.',
        ),
      ];

  static List<TourStep> crmSettings() => [
        step(
          sectionId: 'crm.settings',
          order: 2,
          title: 'Telephony, KPIs, retention, preferences',
          route: '/crm/settings',
          body:
              'Tabs are Elision Telephony A P I, Dashboard K P I Management, Bin and Retention Policy, and General Preferences. Telephony needs click to call U R L, credentials and a webhook. K P I toggles show or hide dashboard tiles. Retention controls bin restore. Preferences include default currency, telecaller calling window, and who may assign sales reps. Test one lead after a change.',
        ),
      ];

  static List<TourStep> orgTree() => [
        step(
          sectionId: 'collab.org_tree',
          order: 2,
          title: 'Tree, graph, contacts',
          route: '/org-tree',
          body:
              'Tabs are Tree, Graph and Contacts. Search finds a person. Admins Generate from Department, lead, team, or Reporting chain, and can Publish for everyone. Rename, Rebuild or Delete a saved tree. Contacts can Add permission with a topic and phone. Fix the manager on Workforce if the tree looks wrong. This is the human chart, not the Roles matrix.',
        ),
      ];

  static List<TourStep> tasks() => [
        step(
          sectionId: 'collab.tasks',
          order: 2,
          title: 'Board: mine, assigned, reviews',
          route: '/tasks',
          body:
              'Board shows Waiting for your review, Extra approvals, My tasks, and Assigned by me. Only first reporting managers get Assign task. Status goes Assigned, Ongoing, Completed, then Changes requested, Approved or Rejected. The assigner reviews completed work. Comment on the task. Do not hide decisions in chat.',
        ),
        step(
          sectionId: 'collab.tasks',
          order: 3,
          title: 'Gantt',
          route: '/tasks',
          clip: 'thinking',
          body:
              'Gantt is dates on a timeline. Use it for overlapping work. Refresh reloads both tabs. A badge on Board means reviews are waiting. Site jobs that are contracts belong in Work Orders, not here.',
        ),
      ];

  static List<TourStep> chat() => [
        step(
          sectionId: 'collab.chat',
          order: 2,
          title: 'Threads, groups, calls',
          route: '/chat',
          body:
              'Left is channels. New starts a direct chat or group. The thread supports attach, emoji, mention, reply, copy, forward, react, edit and delete. Voice call is from the header. Group info and wallpaper are in the room menu. Unread counts hit the sidebar and the bell. Keep policies in Repository. Chat is not leave, payroll or C R M.',
        ),
      ];

  static List<TourStep> meet() => [
        step(
          sectionId: 'collab.meet',
          order: 2,
          title: 'Start now, join, schedule',
          route: '/meet',
          body:
              'Start instant meeting needs title, optional agenda, access and waiting room, then Start now. Join a meeting takes a code. Live now lists rooms in progress. Manage meetings: Schedule, View scheduled, View past, and org meetings. Send the invite from here so people get a notification.',
        ),
        step(
          sectionId: 'collab.meet',
          order: 3,
          title: 'Inside the room',
          route: '/meet',
          clip: 'thinking',
          body:
              'In the room: microphone, camera, speaker, screen share, reactions, raise hand, chat for everyone or direct, people, collaboration board, record, admit waiting room, end or leave. Recordings stay on the meeting. Action items after the call belong in Tasks.',
        ),
      ];
}
