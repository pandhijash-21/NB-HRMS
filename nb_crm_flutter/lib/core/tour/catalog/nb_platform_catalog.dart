import '../models/tour_models.dart';
import 'tour_scripts.dart';

class NbPlatformCatalog {
  NbPlatformCatalog._();

  static TourCatalog build() {
    return TourCatalog([
      _complete(),
      _firstVisit(),
      _quick(),
      _hrms(),
      _erp(),
      _crm(),
      _collaboration(),
    ]);
  }

  static TourModule _complete() {
    return TourModule(
      id: 'platform.complete',
      title: 'Whole Software Tour',
      description: 'Every screen you can access, explained in one walkthrough.',
      category: TourCategory.other,
      sections: [
        TourSection(
          id: 'platform.complete.intro',
          moduleId: 'platform.complete',
          title: 'Whole Software Tour',
          description: 'Start a full walkthrough of NB.',
          estimatedMinutes: 20,
          steps: [
            TourStep(
              id: 'complete.intro',
              sectionId: 'platform.complete.intro',
              title: 'Whole Software Tour',
              description:
                  'I will walk every module your role can open in one go — HRMS, then ERP, then CRM, then Collaboration. When you are allowed to use ERP or CRM I switch that suite so the real screens and sidebar appear, and I explain each page: buttons, tabs, rules and common mistakes. Screens you cannot access stay hidden. Use Next to continue, Skip for one step, Replay voice to hear the card again, or Close to pause. Progress is saved on this device.',
              order: 1,
              type: TourStepType.intro,
              useMascot: true,
              mascotClip: 'welcome',
              targetId: 'shell.brand',
            ),
          ],
        ),
        TourSection(
          id: 'platform.complete.wrapup',
          moduleId: 'platform.complete',
          title: 'Tour complete',
          description: 'Replay any section later.',
          estimatedMinutes: 1,
          steps: [
            TourStep(
              id: 'complete.wrapup',
              sectionId: 'platform.complete.wrapup',
              title: 'You have seen the software',
              description:
                  'That is the in-depth tour of every feature your role can open today, including ERP and CRM when your licence and permissions allow them. Open Software Tour to replay one section or run the whole walkthrough again. If an administrator later grants you a new module, I will offer a short tour of that module the first time only.',
              order: 1,
              type: TourStepType.completion,
              useMascot: true,
              mascotClip: 'thumbs_up',
              targetId: TourIds.nav('/software-tour'),
              route: '/software-tour',
            ),
          ],
        ),
      ],
    );
  }

  static TourModule _firstVisit() {
    return TourModule(
      id: 'platform.first_visit',
      title: 'Welcome',
      description: 'A short orientation to NB CRM — your ERP, CRM and HRMS workspace.',
      category: TourCategory.other,
      sections: [
        TourSection(
          id: 'platform.first_visit.intro',
          moduleId: 'platform.first_visit',
          title: 'Welcome to NB',
          description: 'Meet the platform and the main navigation.',
          estimatedMinutes: 2,
          steps: [
            TourStep(
              id: 'first.welcome',
              sectionId: 'platform.first_visit.intro',
              title: 'Welcome to NB CRM',
              description:
                  'This is your complete business workspace — ERP, CRM and HRMS together in one login. I only show tools your organisation licensed and your role is allowed to open.',
              order: 1,
              type: TourStepType.intro,
              useMascot: true,
              mascotClip: 'welcome',
              targetId: 'shell.brand',
            ),
            TourStep(
              id: 'first.nav',
              sectionId: 'platform.first_visit.intro',
              title: 'Main navigation',
              description:
                  'The left sidebar is the map of the product. Groups such as Main, HR, Organisation, ERP, CRM and Collaboration expand as you need them. Search at the top filters this list. Items you are not allowed to open never appear, so two colleagues can see different menus.',
              order: 2,
              type: TourStepType.navigation,
              useMascot: true,
              mascotClip: 'wave',
              targetId: 'shell.sidebar',
            ),
            TourStep(
              id: 'first.suites',
              sectionId: 'platform.first_visit.intro',
              title: 'ERP, CRM and HRMS',
              description:
                  'This suite switcher (bottom-right) jumps between HRMS, CRM and ERP without logging out. The sidebar then shows that suite’s pages. You only see suites your organisation licensed and your account can access. Super-admins use a separate SaaS console instead of this switcher.',
              order: 3,
              type: TourStepType.information,
              useMascot: true,
              mascotClip: 'pointing',
              targetId: 'shell.suite_switcher',
            ),
            TourStep(
              id: 'first.hub',
              sectionId: 'platform.first_visit.intro',
              title: 'Software Tour',
              description:
                  'Open Software Tour any time from the sidebar. Run a quick look, walk the whole product, or pick individual sections. Progress is stored on this device. The Whole Software Tour visits every screen you can actually use, with a full explanation on each stop.',
              order: 4,
              type: TourStepType.completion,
              useMascot: true,
              mascotClip: 'thumbs_up',
              targetId: TourIds.nav('/software-tour'),
              route: '/software-tour',
            ),
          ],
        ),
      ],
    );
  }

  static TourModule _quick() {
    return TourModule(
      id: 'platform.quick',
      title: 'Quick Tour',
      description: 'A short overview of the shell: home, search, alerts and profile.',
      category: TourCategory.other,
      sections: [
        TourSection(
          id: 'platform.quick.shell',
          moduleId: 'platform.quick',
          title: 'Application shell',
          description: 'Navigation, search, notifications and your profile.',
          estimatedMinutes: 3,
          steps: [
            TourStep(
              id: 'quick.welcome',
              sectionId: 'platform.quick.shell',
              title: 'Quick Tour',
              description:
                  'This short tour covers the controls you use every day — logo, sidebar search and notifications — without visiting every module.',
              order: 1,
              type: TourStepType.intro,
              useMascot: true,
              mascotClip: 'welcome',
              targetId: 'shell.brand',
            ),
            TourStep(
              id: 'quick.search',
              sectionId: 'platform.quick.shell',
              title: 'Find a module',
              description:
                  'Type here to filter the sidebar when the catalog grows. Search matches page names such as Leave, Pre sales or Work Orders. Clear the box to show the full menu again. This does not search records inside a module — open the module first, then use that screen’s own filters.',
              order: 2,
              targetId: 'shell.search',
              mascotClip: 'thinking',
            ),
            TourStep(
              id: 'quick.alerts',
              sectionId: 'platform.quick.shell',
              title: 'Notifications',
              description:
                  'Chat, meeting invites, tracking alerts and approval pings land here. A badge means something needs attention. Open the bell, tap an item to jump to it, and use sound controls if location alerts are enabled for field staff.',
              order: 3,
              targetId: 'shell.notifications',
              mascotClip: 'pointing',
            ),
            TourStep(
              id: 'quick.hub',
              sectionId: 'platform.quick.shell',
              title: 'Keep exploring',
              description:
                  'Software Tour lists every section you are allowed to learn, with progress saved on this device. Start Whole Software Tour when you want the complete walkthrough.',
              order: 4,
              type: TourStepType.completion,
              useMascot: true,
              mascotClip: 'thumbs_up',
              targetId: TourIds.nav('/software-tour'),
              route: '/software-tour',
            ),
          ],
        ),
      ],
    );
  }

  static TourModule _hrms() {
    const suite = TourPermissionReq(suite: 'HRMS');
    return TourModule(
      id: 'hrms',
      title: 'HRMS',
      description: 'People, attendance, leave, payroll, organisation and tracking.',
      category: TourCategory.hrms,
      permission: suite,
      sections: [
        _section(
          id: 'hrms.dashboard',
          moduleId: 'hrms',
          title: 'Admin dashboard',
          description: 'Workforce snapshot for managers.',
          howTo:
              'The admin dashboard is the HRMS command centre. Refresh reloads live counts for employees, active staff, departments and pending tasks. Charts show department mix, growth trend and category split. Use it to see what needs attention, then open the real module. You only see this page if you can enter the admin portal.',
          extra: TourScripts.dashboard(),
          permission: const TourPermissionReq(
            suite: 'HRMS',
            anyOf: [
              TourPermissionReq(module: 'REPORTS'),
              TourPermissionReq(module: 'USER_MGMT'),
              TourPermissionReq(module: 'PAYROLL'),
              TourPermissionReq(module: 'SALARY'),
              TourPermissionReq(module: 'FIELD_MGMT'),
            ],
          ),
          route: '/admin/dashboard',
          targetId: TourIds.nav('/admin/dashboard'),
        ),
        _section(
          id: 'hrms.home',
          moduleId: 'hrms',
          title: 'Home',
          description: 'Your HRMS launchpad and module cards.',
          howTo:
              'Home is the HRMS launchpad. Each card is a tool you are allowed to open — Profile, Leave, Attendance, and so on. Cards you cannot use stay hidden. Tap a card to go there. This is the safest place to start after login if you are not an admin.',
          permission: suite,
          route: '/home',
          targetId: TourIds.nav('/home'),
          extra: TourScripts.hrmsHome(),
        ),
        _section(
          id: 'hrms.profile',
          moduleId: 'hrms',
          title: 'Profile',
          description: 'Your employee record, documents and salary slips.',
          howTo:
              'Profile is your employee record. Review personal details, education, experience, documents and salary slips. Edits to sensitive fields often need HR approval — submit the change and watch Profile Approvals if you are a manager. Keep contact and bank details current so payroll and letters stay correct.',
          permission: suite,
          route: '/profile',
          targetId: TourIds.nav('/profile'),
          extra: TourScripts.profile(),
        ),
        _section(
          id: 'hrms.leave',
          moduleId: 'hrms',
          title: 'Leave',
          description: 'Balances, apply, history and approvals.',
          howTo:
              'Leave has four jobs: see balances, apply, review history, and (if you approve others) clear pending requests. Apply with type, dates and a reason. Attach a document when policy asks. History shows status — pending, approved, rejected. Approvers get a queue; company holidays and leave types live under admin leave settings if you have that access.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'LEAVE'),
          route: '/leave',
          targetId: TourIds.nav('/leave'),
          extra: TourScripts.leave(),
        ),
        _section(
          id: 'hrms.attendance',
          moduleId: 'hrms',
          title: 'Attendance',
          description: 'Punch, history and locations.',
          howTo:
              'Attendance is punch in and out, plus your history. If the organisation uses geofencing, you must be inside the allowed location. Device attendance and admin location lists are separate screens for HR. Check today’s punch before you leave site so the day closes cleanly.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'ATTENDANCE'),
          route: '/attendance',
          targetId: TourIds.nav('/attendance'),
          extra: TourScripts.attendance(),
        ),
        _section(
          id: 'hrms.reimbursements',
          moduleId: 'hrms',
          title: 'Reimbursements',
          description: 'Submit and track expense claims.',
          howTo:
              'Reimbursements is expense claims. Create a claim with category, amount, date and receipts, then submit. Track pending versus paid. Finance or HR with admin reimbursement permission sees the approval queue. Keep receipts readable — unclear files delay payment.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'REIMBURSEMENTS'),
          route: '/reimbursements',
          targetId: TourIds.nav('/reimbursements'),
          extra: TourScripts.reimbursements(),
        ),
        _section(
          id: 'hrms.recruitment',
          moduleId: 'hrms',
          title: 'Recruitment',
          description: 'Candidates and hiring pipeline.',
          howTo:
              'Recruitment is the hiring pipeline: openings, candidates and status. Open a candidate to see resume, notes and stage. Move people through screening, interview and offer only if you have write access. Do not store offer letters only in chat — attach them on the candidate record.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'RECRUITMENT'),
          route: '/recruitment',
          targetId: TourIds.nav('/recruitment'),
          extra: TourScripts.recruitment(),
        ),
        _section(
          id: 'hrms.repository',
          moduleId: 'hrms',
          title: 'Repository',
          description: 'Company documents and shared files.',
          howTo:
              'Repository is shared company files: policies, templates and department folders. Download what you need. Upload and organise only if you have manage-repository permission. Prefer this over chat attachments for documents everyone must keep.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'REPOSITORY'),
          route: '/repository',
          targetId: TourIds.nav('/repository'),
          extra: TourScripts.repository(),
        ),
        _section(
          id: 'hrms.payroll',
          moduleId: 'hrms',
          title: 'Payroll',
          description: 'Salary structures, payroll runs and slips.',
          howTo:
              'Payroll is salary structures, monthly runs and slips. HR sets structures, runs payroll for a month, then staff download slips from Profile. Fix bank and tax data before you run a month — corrections after publish are harder. You only see this if you have payroll or salary permission.',
          permission: const TourPermissionReq(
            suite: 'HRMS',
            anyOf: [
              TourPermissionReq(module: 'PAYROLL'),
              TourPermissionReq(module: 'SALARY'),
            ],
          ),
          route: '/admin/salary/payroll',
          targetId: TourIds.nav('/admin/salary/payroll'),
          extra: TourScripts.payroll(),
        ),
        _section(
          id: 'hrms.workforce',
          moduleId: 'hrms',
          title: 'Workforce',
          description: 'Employee directory and records.',
          howTo:
              'Workforce is the employee directory. Open a person for job, institute, reporting manager and status. Create or update records if you can write personal info. This is the source of truth for leave, attendance and payroll — keep designations and joining dates accurate.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'PERSONAL_INFO'),
          route: '/admin/employees',
          targetId: TourIds.nav('/admin/employees'),
          extra: TourScripts.workforce(),
        ),
        _section(
          id: 'hrms.users',
          moduleId: 'hrms',
          title: 'Users',
          description: 'Login accounts mapped to employees.',
          howTo:
              'Users are login accounts mapped to employees. Create a user only after the employee exists, assign a role, and disable leavers instead of leaving stale passwords. Employee ID plus date of birth is the usual first-login pattern. Never share admin accounts.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'USER_MGMT'),
          route: '/admin/users',
          targetId: TourIds.nav('/admin/users'),
          extra: TourScripts.users(),
        ),
        _section(
          id: 'hrms.roles',
          moduleId: 'hrms',
          title: 'Roles',
          description: 'Role matrix — the same permissions that filter this tour.',
          howTo:
              'Roles is the permission matrix. Each role lists modules (Leave, Projects, CRM Pre-sales…) and actions (READ, WRITE). This tour uses the same matrix — if a screen is missing, the role does not grant it. Change roles carefully: too wide exposes payroll and CRM; too narrow blocks daily work.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'ROLE_MGMT'),
          route: '/admin/roles',
          targetId: TourIds.nav('/admin/roles'),
          extra: TourScripts.roles(),
        ),
        _section(
          id: 'hrms.configurations',
          moduleId: 'hrms',
          title: 'Configurations',
          description: 'Organisations, institutes, designations and lookups.',
          howTo:
              'Configurations holds organisation setup: companies, institutes, designations and shared lookups. Change these before you add a large batch of employees. Wrong institute or designation on a person breaks org tree, letters and reports.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'USER_MGMT'),
          route: '/admin/configurations',
          targetId: TourIds.nav('/admin/configurations'),
          extra: TourScripts.configurations(),
        ),
        _section(
          id: 'hrms.storage',
          moduleId: 'hrms',
          title: 'Storage',
          description: 'File quotas and uploaded documents.',
          howTo:
              'Storage shows how much file space the organisation is using: profile photos, letters, chat and Cloudinary if it is configured. Admins watch quotas here. Ordinary staff do not upload from this page — they attach files on Profile, Repository or Chat. If the bar is full, old files must be cleared before new letters will save.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'USER_MGMT'),
          route: '/admin/storage',
          targetId: TourIds.nav('/admin/storage'),
          extra: TourScripts.storage(),
        ),
        _section(
          id: 'hrms.audit',
          moduleId: 'hrms',
          title: 'Audit',
          description: 'Who changed what, and when.',
          howTo:
              'Audit is the activity log: logins, permission changes, employee edits and other sensitive actions. Filter by person and date when something looks wrong. This is a record, not a chat. You need admin portal access to open it.',
          permission: const TourPermissionReq(
            suite: 'HRMS',
            anyOf: [
              TourPermissionReq(module: 'USER_MGMT'),
              TourPermissionReq(module: 'ROLE_MGMT'),
              TourPermissionReq(module: 'REPORTS'),
            ],
          ),
          route: '/admin/audit',
          targetId: TourIds.nav('/admin/audit'),
          extra: TourScripts.audit(),
        ),
        _section(
          id: 'hrms.approvals',
          moduleId: 'hrms',
          title: 'Profile approvals',
          description: 'Review employee profile change requests.',
          howTo:
              'Profile Approvals is the HR queue for employee-submitted profile edits. Approve correct updates, reject errors with a note. Do not leave this queue idle — pending changes block payroll and letters that need the new data.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'PERSONAL_INFO'),
          route: '/admin/approvals',
          targetId: TourIds.nav('/admin/approvals'),
          extra: TourScripts.approvals(),
        ),
        _section(
          id: 'hrms.earth',
          moduleId: 'hrms',
          title: 'NB Earth',
          description: 'Organisation globe and sites.',
          howTo:
              'NB Earth is the organisation globe. Sites and offices appear on the map so you can see where the company operates. Use it for orientation, not for live staff GPS — that is Live Tracking and Tracking Hub.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'GOOGLE_EARTH'),
          route: '/admin/earth',
          targetId: TourIds.nav('/admin/earth'),
          extra: TourScripts.earth(),
        ),
        _section(
          id: 'hrms.earth_dashboard',
          moduleId: 'hrms',
          title: 'Earth dashboard',
          description: 'Insights for mapped sites.',
          howTo:
              'Earth Dashboard summarises mapped sites and related insights. Use it after NB Earth when you need counts and comparisons rather than the globe itself.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'GOOGLE_EARTH'),
          route: '/admin/earth/dashboard',
          targetId: TourIds.nav('/admin/earth/dashboard'),
          extra: TourScripts.earthDashboard(),
        ),
        _section(
          id: 'hrms.live_tracking',
          moduleId: 'hrms',
          title: 'Live tracking',
          description: 'See field staff on the map now.',
          howTo:
              'Live Tracking shows field staff on the map right now. Open a person for last point, speed and trail. Location alerts can sound when someone leaves a geofence. Use this during the working day; use Trips for history.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'FIELD_MGMT'),
          route: '/admin/live-tracking',
          targetId: TourIds.nav('/admin/live-tracking'),
          extra: TourScripts.liveTracking(),
        ),
        _section(
          id: 'hrms.trips',
          moduleId: 'hrms',
          title: 'Trips',
          description: 'Past field routes and stops.',
          howTo:
              'Trips is historical field movement: start, end, route and stops. Open a trip to replay the path. Use it for mileage, site visits and exception review. Live Tracking is current; Trips is the archive.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'FIELD_MGMT'),
          route: '/admin/trips',
          targetId: TourIds.nav('/admin/trips'),
          extra: TourScripts.trips(),
        ),
        _section(
          id: 'hrms.tracking',
          moduleId: 'hrms',
          title: 'Tracking Hub',
          description: 'Live tracking, trips and field insights together.',
          howTo:
              'Tracking Hub combines live map, trips and field insights, including alert counts. Start here if you manage field staff daily. The sidebar badge follows this hub when alerts are open.',
          permission: const TourPermissionReq(suite: 'HRMS', module: 'FIELD_MGMT'),
          route: '/admin/tracking-hub',
          targetId: TourIds.nav('/admin/tracking-hub'),
          extra: TourScripts.trackingHub(),
        ),
      ],
    );
  }

  static TourModule _erp() {
    const suite = TourPermissionReq(suite: 'ERP');
    return TourModule(
      id: 'erp',
      title: 'ERP',
      description: 'Projects, work orders, BOQ, store, tenders and DPR.',
      category: TourCategory.erp,
      permission: suite,
      sections: [
        _section(
          id: 'erp.home',
          moduleId: 'erp',
          title: 'ERP Home',
          description: 'Tiles for every ERP tool assigned to you.',
          howTo:
              'ERP Home is the construction operations launchpad. Tiles open Projects, Work Orders, BOQ, Store, Tenders, DPR and Configurations. Switch to the ERP suite with the bottom-right button if you arrived from HRMS or CRM. Missing tiles mean missing permission, not a bug.',
          permission: suite,
          route: '/erp/home',
          targetId: TourIds.nav('/erp/home'),
          extra: TourScripts.erpHome(),
        ),
        _section(
          id: 'erp.projects',
          moduleId: 'erp',
          title: 'Projects',
          description: 'Sites, towers and units.',
          howTo:
              'Projects are sites. Open a project for towers and units. Create a project with name, location and codes before work orders or BOQ. Unit status (available, sold, blocked) is used by CRM post-sales — keep it current so sales and site teams share one list.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'PROJECTS'),
          route: '/erp/projects',
          targetId: TourIds.nav('/erp/projects'),
          extra: TourScripts.projects(),
        ),
        _section(
          id: 'erp.work_orders',
          moduleId: 'erp',
          title: 'Work Orders',
          description: 'Issue and track work orders.',
          howTo:
              'Work Orders assign a job to a contractor or team on a project. Create an order with scope, dates and references, then track status through issue, progress and close. Link the correct project so BOQ and DPR line up. Do not duplicate the same job as a Task unless it is office follow-up.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'WORK_ORDERS'),
          route: '/erp/work-orders',
          targetId: TourIds.nav('/erp/work-orders'),
          extra: TourScripts.workOrders(),
        ),
        _section(
          id: 'erp.boq',
          moduleId: 'erp',
          title: 'BOQ',
          description: 'Bills of quantities for a project.',
          howTo:
              'BOQ is the bill of quantities: items, units and amounts for a project. Create or import a BOQ, then keep quantities in line with site reality. Store issues and DPR progress should be reconcilable against this list. Lock versions when a tender or contract is based on them.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'BOQ'),
          route: '/erp/boq',
          targetId: TourIds.nav('/erp/boq'),
          extra: TourScripts.boq(),
        ),
        _section(
          id: 'erp.store',
          moduleId: 'erp',
          title: 'Store',
          description: 'Materials and store configuration.',
          howTo:
              'Store is materials: stock, receipts and issues against projects. Configure items and units first, then record inward and outward. Wrong UOM or project on an issue corrupts consumption reports. Use Configurations for item masters if the list is empty.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'STORE'),
          route: '/erp/store',
          targetId: TourIds.nav('/erp/store'),
          extra: TourScripts.store(),
        ),
        _section(
          id: 'erp.tenders',
          moduleId: 'erp',
          title: 'Tenders',
          description: 'Tenders and applications.',
          howTo:
              'Tenders lists bid packages you publish or track. Open a tender for dates, documents and status. Applications (next stop, if you have access) are responses from bidders. Keep closing dates honest — late edits confuse applicants.',
          permission: const TourPermissionReq(
            suite: 'ERP',
            anyOf: [
              TourPermissionReq(module: 'TENDERS'),
              TourPermissionReq(module: 'TENDER_APPLICATIONS'),
            ],
          ),
          route: '/erp/tenders',
          targetId: TourIds.nav('/erp/tenders'),
          extra: TourScripts.tenders(),
        ),
        _section(
          id: 'erp.tender_applications',
          moduleId: 'erp',
          title: 'Tender applications',
          description: 'Bidder responses to tenders.',
          howTo:
              'Tender Applications are bidder responses. Open an application for commercials, documents and decision. Record award or rejection here so the tender status stays true. You need tender-application permission even if you can already view tenders.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'TENDER_APPLICATIONS'),
          route: '/erp/tender-applications',
          targetId: TourIds.nav('/erp/tender-applications'),
          extra: TourScripts.tenderApps(),
        ),
        _section(
          id: 'erp.dpr',
          moduleId: 'erp',
          title: 'DPR',
          description: 'Daily progress reports.',
          howTo:
              'DPR is the daily progress report from site: work done, labour, materials and blockers. Submit for the correct project and date. Managers read this instead of waiting for a WhatsApp summary. Late DPRs leave the dashboard empty — file the same day when possible.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'DPR'),
          route: '/erp/dpr',
          targetId: TourIds.nav('/erp/dpr'),
          extra: TourScripts.dpr(),
        ),
        _section(
          id: 'erp.config',
          moduleId: 'erp',
          title: 'ERP Configurations',
          description: 'Activities, contractors, materials and lookups.',
          howTo:
              'ERP Configurations is the master data for operations: activities, contractors, materials and lookups used on project and DPR forms. Set these up before the first project. Changing a contractor name later does not rewrite old work orders — edit with care.',
          permission: const TourPermissionReq(suite: 'ERP', module: 'ERP_CONFIGURATIONS'),
          route: '/erp/configurations',
          targetId: TourIds.nav('/erp/configurations'),
          extra: TourScripts.erpConfig(),
        ),
      ],
    );
  }

  static TourModule _crm() {
    const suite = TourPermissionReq(suite: 'CRM');
    return TourModule(
      id: 'crm',
      title: 'CRM',
      description: 'Pre-sales, post-sales, headers, bin and settings.',
      category: TourCategory.crm,
      permission: suite,
      sections: [
        _section(
          id: 'crm.dashboard',
          moduleId: 'crm',
          title: 'CRM Dashboard',
          description: 'Pipeline snapshot and CRM shortcuts.',
          howTo:
              'CRM Dashboard is the sales snapshot: pipeline, shortcuts into pre-sales and post-sales, and counts you can act on. Switch to the CRM suite if the sidebar still shows HRMS. Use this page in the morning; use Pre sales to work the list.',
          permission: const TourPermissionReq(suite: 'CRM', module: 'CRM_DASHBOARD'),
          route: '/crm/dashboard',
          targetId: TourIds.nav('/crm/dashboard'),
          extra: TourScripts.crmDashboard(),
        ),
        _section(
          id: 'crm.pre_sales',
          moduleId: 'crm',
          title: 'Pre sales',
          description: 'Leads and opportunities before handover.',
          howTo:
              'Pre sales is the live working list: add a lead, capture source and project interest, log follow-ups, and move status toward booking. Use filters before you export. Headers (when visible) control which columns appear — ask an admin before you invent a spreadsheet on the side.',
          permission: const TourPermissionReq(suite: 'CRM', module: 'CRM_PRE_SALES'),
          route: '/crm/pre-sales',
          targetId: TourIds.nav('/crm/pre-sales'),
          extra: TourScripts.preSales(),
        ),
        _section(
          id: 'crm.headers',
          moduleId: 'crm',
          title: 'Headers',
          description: 'CRM header configuration used by pre-sales.',
          howTo:
              'Headers configure pre-sales columns and field labels for your organisation. Add a header only when a real process needs a new field. Renaming or hiding a header changes what every salesperson sees — coordinate with the CRM owner.',
          permission: const TourPermissionReq(suite: 'CRM', module: 'CRM_HEADERS'),
          route: '/crm/pre-sales/headers',
          targetId: TourIds.nav('/crm/pre-sales/headers'),
          extra: TourScripts.headers(),
        ),
        _section(
          id: 'crm.post_sales',
          moduleId: 'crm',
          title: 'Post sales',
          description: 'Handover and after-sales records.',
          howTo:
              'Post sales is after booking: handover, unit, customer care and after-sales notes. Keep the unit in sync with ERP Projects. Log complaints and closures here so history is searchable. Pre-sales is demand; post-sales is delivery.',
          permission: const TourPermissionReq(suite: 'CRM', module: 'CRM_POST_SALES'),
          route: '/crm/post-sales',
          targetId: TourIds.nav('/crm/post-sales'),
          extra: TourScripts.postSales(),
        ),
        _section(
          id: 'crm.bin',
          moduleId: 'crm',
          title: 'Bin',
          description: 'Archived CRM records.',
          howTo:
              'Bin holds archived CRM rows. Restore a record if it was closed by mistake; otherwise leave it here so the live pre-sales list stays clean. Deleting from bin (if allowed) is permanent — prefer archive.',
          permission: const TourPermissionReq(suite: 'CRM', module: 'CRM_BIN'),
          route: '/crm/bin',
          targetId: TourIds.nav('/crm/bin'),
          extra: TourScripts.bin(),
        ),
        _section(
          id: 'crm.settings',
          moduleId: 'crm',
          title: 'CRM Settings',
          description: 'CRM configuration for your organisation.',
          howTo:
              'CRM Settings is organisation-level CRM config, not your user profile. Change sources, defaults and process options here. Test with one lead after a change before you announce it to the sales floor.',
          permission: const TourPermissionReq(suite: 'CRM', module: 'CRM_SETTINGS'),
          route: '/crm/settings',
          targetId: TourIds.nav('/crm/settings'),
          extra: TourScripts.crmSettings(),
        ),
      ],
    );
  }

  static TourModule _collaboration() {
    return TourModule(
      id: 'collaboration',
      title: 'Collaboration',
      description: 'Org tree, tasks, chat and meetings — shared across suites.',
      category: TourCategory.collaboration,
      sections: [
        _section(
          id: 'collab.org_tree',
          moduleId: 'collaboration',
          title: 'Employee tree',
          description: 'Reporting hierarchy and who to contact.',
          howTo:
              'Employee tree is the reporting hierarchy. Find who reports to whom, and who to contact for an approval. It is built from Workforce manager fields — fix the person record if the tree looks wrong. This is not a substitute for Roles; it is the human org chart.',
          permission: const TourPermissionReq(module: 'ORG_TREE'),
          route: '/org-tree',
          targetId: TourIds.nav('/org-tree'),
          extra: TourScripts.orgTree(),
        ),
        _section(
          id: 'collab.tasks',
          moduleId: 'collaboration',
          title: 'Tasks',
          description: 'Assign work, subtasks and Gantt.',
          howTo:
              'Tasks is office work: create a task, assign an owner, set dates, add subtasks and watch Gantt. Use this for follow-ups that are not a Work Order or a CRM lead. Comment on the task instead of a side chat so the history stays on the record.',
          permission: const TourPermissionReq(module: 'TASKS'),
          route: '/tasks',
          targetId: TourIds.nav('/tasks'),
          extra: TourScripts.tasks(),
        ),
        _section(
          id: 'collab.chat',
          moduleId: 'collaboration',
          title: 'Chat',
          description: '1:1 and group messaging.',
          howTo:
              'Chat is 1:1 and group messaging inside NB. Unread counts appear on the sidebar and in the notification bell. Use groups for teams; keep files you must retain in Repository. Chat is not the leave, payroll or CRM system of record.',
          permission: const TourPermissionReq(module: 'CHAT'),
          route: '/chat',
          targetId: TourIds.nav('/chat'),
          extra: TourScripts.chat(),
        ),
        _section(
          id: 'collab.meet',
          moduleId: 'collaboration',
          title: 'Meet',
          description: 'Schedule and join meetings.',
          howTo:
              'Meet is video meetings: schedule, join, see upcoming and past. Send the link from here so attendees get a notification. Recordings (when enabled) stay with the meeting, not in chat. Use Tasks if you need action items after the call.',
          permission: const TourPermissionReq(module: 'MEETINGS'),
          route: '/meet',
          targetId: TourIds.nav('/meet'),
          extra: TourScripts.meet(),
        ),
      ],
    );
  }

  static TourSection _section({
    required String id,
    required String moduleId,
    required String title,
    required String description,
    required String route,
    required String targetId,
    String? howTo,
    TourPermissionReq? permission,
    List<TourStep> extra = const [],
    String? clip,
  }) {
    return TourSection(
      id: id,
      moduleId: moduleId,
      title: title,
      description: description,
      permission: permission,
      estimatedMinutes: extra.isEmpty ? 2 : 2 + extra.length,
      steps: [
        TourStep(
          id: '$id.intro',
          sectionId: id,
          title: title,
          description: howTo ?? description,
          order: 1,
          route: route,
          targetId: targetId,
          type: TourStepType.intro,
          useMascot: true,
          mascotClip: clip ?? 'welcome',
          permission: permission,
        ),
        ...extra.map(
          (s) => TourStep(
            id: s.id,
            sectionId: s.sectionId,
            title: s.title,
            description: s.description,
            order: s.order,
            targetId: s.targetId ??
                (s.route != null
                    ? TourIds.step(s.sectionId, s.order)
                    : targetId),
            route: s.route ?? route,
            mascotClip: s.mascotClip,
            type: s.type,
            placement: s.placement,
            autoScroll: s.autoScroll,
            required: s.required,
            useMascot: s.useMascot,
            permission: s.permission ?? permission,
            includeInComplete: s.includeInComplete,
          ),
        ),
        TourStep(
          id: '$id.done',
          sectionId: id,
          title: 'Section complete',
          description: 'You have finished $title. Continue to the next selected tour or return to Software Tour.',
          order: 90,
          type: TourStepType.completion,
          useMascot: true,
          mascotClip: 'thumbs_up',
          targetId: targetId,
          route: route,
          permission: permission,
          includeInComplete: false,
        ),
      ],
    );
  }
}
