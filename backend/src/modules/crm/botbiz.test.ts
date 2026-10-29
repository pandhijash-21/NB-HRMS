/**
 * Automated Tests for BotBiz WhatsApp Integration
 * Uses mocked HTTP responses to test BotBizApiClient and WhatsappService.
 * Never sends real messages to customers.
 */

import { BotBizApiClient } from './botbiz.client';
import { WhatsappService } from './whatsapp.service';

// Mock global fetch
const originalFetch = global.fetch;

function mockFetchResponse(status: number, body: any) {
  global.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    return {
      ok: status >= 200 && status < 300,
      status,
      text: async () => (typeof body === 'string' ? body : JSON.stringify(body)),
      json: async () => (typeof body === 'string' ? JSON.parse(body) : body),
    } as any;
  };
}

async function runTests() {
  console.log('🧪 Starting BotBiz WhatsApp Integration Test Suite...\n');
  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string) {
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${testName}`);
      failed++;
    }
  }

  // Test 1: Phone number normalization
  {
    console.log('Test Suite 1: Phone Normalization');
    assert(
      BotBizApiClient.normalizePhoneNumber('9876543210') === '919876543210',
      'Normalizes 10-digit Indian number to include 91 country code',
    );
    assert(
      BotBizApiClient.normalizePhoneNumber('+91 98765 43210') === '919876543210',
      'Strips non-digit characters and spaces',
    );
    assert(
      BotBizApiClient.normalizePhoneNumber('14155552671') === '14155552671',
      'Preserves international number with existing country code',
    );
  }

  // Test 2: Free-form text message dispatch with status: "1"
  {
    console.log('\nTest Suite 2: Send Text Message (POST /whatsapp/send)');
    let capturedBody = '';
    let capturedContentType = '';

    global.fetch = async (url: any, init: any) => {
      capturedBody = init?.body?.toString() || '';
      capturedContentType = init?.headers?.['Content-Type'] || '';
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({
            status: '1',
            wa_message_id: 'wamid.HBgLMTIzNDU2Nzg5MA==',
            message: 'Message sent successfully.',
          }),
      } as any;
    };

    const client = new BotBizApiClient({
      apiBase: 'https://dash.botbiz.io/api/v1',
      apiToken: 'mock_token_abc123',
      phoneNumberId: 'phone_id_999',
    });

    const res = await client.sendTextMessage({
      phoneNumber: '9876543210',
      message: 'Hello Customer! Site visit confirmed.',
    });

    assert(res.success === true, 'Returns success: true for status "1"');
    assert(res.status === '1', 'Treats status "1" as success indicator');
    assert(
      res.waMessageId === 'wamid.HBgLMTIzNDU2Nzg5MA==',
      'Captures wa_message_id from response',
    );
    assert(
      capturedContentType === 'application/x-www-form-urlencoded',
      'Uses application/x-www-form-urlencoded as documented',
    );
    assert(
      capturedBody.includes('apiToken=mock_token_abc123'),
      'Includes apiToken in form body',
    );
    assert(
      capturedBody.includes('phone_number_id=phone_id_999'),
      'Includes phone_number_id in form body',
    );
    assert(
      capturedBody.includes('phone_number=919876543210'),
      'Includes normalized phone_number in form body',
    );
  }

  // Test 3: BotBiz Error handling (status: "0" and 403 Access Denied)
  {
    console.log('\nTest Suite 3: BotBiz API Error Handling');

    // 403 Access Denied simulation (user reported 403 on token generation)
    mockFetchResponse(403, {
      status: '0',
      message: 'Access Denied: Invalid permissions',
    });

    const client = new BotBizApiClient({
      apiBase: 'https://dash.botbiz.io/api/v1',
      apiToken: 'unauthorized_token',
      phoneNumberId: 'phone_id_999',
    });

    const res403 = await client.sendTextMessage({
      phoneNumber: '9876543210',
      message: 'Test message',
    });

    assert(res403.success === false, 'Handles 403 as success: false');
    assert(
      res403.error?.includes('403 Access Denied') === true,
      'Identifies 403 Access Denied error clearly',
    );

    // status: "0" failure
    mockFetchResponse(200, {
      status: '0',
      message: 'Subscriber monthly message limit reached',
    });

    const resLimit = await client.sendTextMessage({
      phoneNumber: '9876543210',
      message: 'Test message',
    });

    assert(resLimit.success === false, 'Identifies status "0" as failure');
    assert(
      resLimit.message.includes('Subscriber monthly message limit reached'),
      'Passes through provider error message',
    );

    // HTTP 200 + null wa_message_id must NOT look like success (false "message sent")
    mockFetchResponse(200, {
      status: '0',
      wa_message_id: null,
      message: 'Queued but rejected by WhatsApp',
    });
    const resNullId = await client.sendTextMessage({
      phoneNumber: '9876543210',
      message: 'Test message',
    });
    assert(
      resNullId.success === false,
      'Does not treat wa_message_id: null as success',
    );
  }

  // Test 4: Fetch templates (POST /whatsapp/get/template/list)
  {
    console.log('\nTest Suite 4: Fetch Templates (POST /whatsapp/get/template/list)');
    mockFetchResponse(200, {
      status: '1',
      data: [
        {
          id: 'tmpl_101',
          name: 'site_visit_reminder',
          language: 'en_US',
          category: 'UTILITY',
          status: 'APPROVED',
          components: [
            {
              type: 'HEADER',
              format: 'TEXT',
              example: { header_text: ['Legacy Tower'] },
            },
            {
              type: 'BODY',
              text: 'Hello {{name}}, site visit at {{date}}',
              example: { body_text: [['Sample Person', '01/01/2026']] },
            },
          ],
        },
        {
          id: 'tmpl_102',
          name: 'welcome_offer',
          language: 'en_US',
          category: 'MARKETING',
          status: 'PENDING',
          header_type: 'DOCUMENT',
          header_url: 'https://cdn.example.com/brochure.pdf',
        },
      ],
    });

    const client = new BotBizApiClient({
      apiBase: 'https://dash.botbiz.io/api/v1',
      apiToken: 'mock_token',
      phoneNumberId: 'phone_id_999',
    });

    const tmplRes = await client.getTemplateList();
    assert(tmplRes.success === true, 'Successfully calls template list endpoint');
    assert(tmplRes.templates.length === 2, 'Parses 2 templates');
    assert(
      tmplRes.templates[0].status === 'APPROVED',
      'Normalizes APPROVED status',
    );
    assert(
      tmplRes.templates[1].status === 'PENDING',
      'Normalizes PENDING status',
    );
    assert(
      tmplRes.templates[0].headerFormat === 'text',
      'Parses TEXT header format from components',
    );
    assert(
      JSON.stringify(tmplRes.templates[0].bodyExampleVariables) ===
        JSON.stringify(['name', 'date']),
      'Uses placeholder names from body text, not Meta example sample values',
    );
    assert(
      tmplRes.templates[1].headerFormat === 'document',
      'Falls back to item.header_type when components missing',
    );
    assert(
      tmplRes.templates[1].headerExampleUrl === 'https://cdn.example.com/brochure.pdf',
      'Reads header media URL from flat BotBiz fields',
    );
  }

  // Test 5: Check template approval status (POST /whatsapp/template/status)
  {
    console.log(
      '\nTest Suite 5: Check Template Status (POST /whatsapp/template/status)',
    );
    let authHeader = '';
    let requestBody: any = {};

    global.fetch = async (url: any, init: any) => {
      authHeader = init?.headers?.['Authorization'] || '';
      requestBody = JSON.parse(init?.body?.toString() || '{}');
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({
            status: '1',
            template_status: 'APPROVED',
            message: 'Template is approved and ready to use',
          }),
      } as any;
    };

    const client = new BotBizApiClient({
      apiBase: 'https://dash.botbiz.io/api/v1',
      apiToken: 'secret_key_123',
      phoneNumberId: 'phone_id_456',
    });

    const statusRes = await client.getTemplateStatus('tmpl_101');
    assert(statusRes.success === true, 'Status check succeeds');
    assert(statusRes.status === 'APPROVED', 'Returns normalized APPROVED status');
    assert(
      authHeader === 'Bearer secret_key_123',
      'Sends Bearer token in Authorization header as documented',
    );
    assert(
      requestBody.phone_number_id === 'phone_id_456',
      'Sends phone_number_id in JSON body',
    );
    assert(
      requestBody.template_id === 'tmpl_101',
      'Sends template_id in JSON body',
    );
  }

  // Test 5b: name-only template must not receive time in the name slot
  {
    console.log('\nTest Suite 5b: Name-only template variable binding');
    let capturedBody = '';
    global.fetch = async (_url: any, init: any) => {
      capturedBody = init?.body?.toString() || '';
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({
            status: '1',
            wa_message_id: 'wamid.name_only_test',
            message: 'Message sent successfully.',
          }),
      } as any;
    };

    const client = new BotBizApiClient({
      apiBase: 'https://dash.botbiz.io/api/v1',
      apiToken: 'mock_token',
      phoneNumberId: 'phone_id_999',
    });

    await client.sendTemplateMessage({
      phoneNumber: '9876543210',
      templateId: '417875',
      templateName: 'cal',
      allowedVariableNames: ['name'],
      variables: {
        name: 'Aarav Patel',
        customerName: 'Aarav Patel',
        date: '30/10/2026',
        time: '12:00 PM',
        siteVisitTime: '12:00 PM',
        projectName: 'NB Legacy Tower',
        calendarLink: 'https://calendar.google.com/example',
      },
    });

    assert(
      capturedBody.includes('templateVariable-name-1=Aarav+Patel') ||
        capturedBody.includes('templateVariable-name-1=Aarav%20Patel'),
      'Sends lead name into templateVariable-name-1',
    );
    assert(
      !capturedBody.includes('templateVariable-name-1=12%3A00') &&
        !capturedBody.includes('templateVariable-name-1=12%3A00+PM') &&
        !capturedBody.includes('templateVariable-name-1=12%3A00%20PM'),
      'Does not put visit time into the name variable',
    );
    assert(
      !capturedBody.includes('templateVariable-calendarLink-1='),
      'Does not dump unrelated CRM fields (calendarLink) when not allowed',
    );
    assert(
      capturedBody.includes('templateVariable-time-1=12') ||
        capturedBody.includes('templateVariable-3=12'),
      'Still sends time into its own slot (not the name slot)',
    );
    assert(
      capturedBody.includes('templateVariable-date-1=30') ||
        capturedBody.includes('templateVariable-2=30'),
      'Still sends date into its own slot',
    );
    assert(
      capturedBody.includes('templateVariable-1=Aarav+Patel') ||
        capturedBody.includes('templateVariable-1=Aarav%20Patel'),
      'Also fills Meta {{1}} with the lead name for name-only templates',
    );

    // Pre-sales path: name + date + time in separate slots (name must not become time)
    capturedBody = '';
    await client.sendTemplateMessage({
      phoneNumber: '9876543210',
      templateId: '417875',
      templateName: 'cal',
      variables: {
        name: 'Aarav Patel',
        customerName: 'Aarav Patel',
        date: '29/10/2026',
        time: '12:32 PM',
        siteVisitTime: '12:32 PM',
      },
    });
    assert(
      capturedBody.includes('templateVariable-name-1=Aarav+Patel') ||
        capturedBody.includes('templateVariable-name-1=Aarav%20Patel'),
      'Pre-sales sends person name into name slot',
    );
    assert(
      capturedBody.includes('templateVariable-1=Aarav+Patel') ||
        capturedBody.includes('templateVariable-1=Aarav%20Patel'),
      'Pre-sales keeps {{1}} as person name (not time)',
    );
    assert(
      !capturedBody.includes('templateVariable-1=12') &&
        !capturedBody.includes('templateVariable-name-1=12'),
      'Pre-sales does not put clock time into name/{{1}}',
    );
    assert(
      capturedBody.includes('templateVariable-date-1=29') ||
        capturedBody.includes('templateVariable-2=29'),
      'Pre-sales sends date into date/{{2}} slot',
    );
    assert(
      capturedBody.includes('templateVariable-time-1=12') ||
        capturedBody.includes('templateVariable-3=12'),
      'Pre-sales sends time into time/{{3}} slot',
    );

    // Project must never become the greeting ("Dear Legacy Tower")
    capturedBody = '';
    await client.sendTemplateMessage({
      phoneNumber: '9876543210',
      templateId: '417875',
      templateName: 'cal',
      allowedVariableNames: ['name', 'date', 'time'],
      templateHeaderText: 'Legacy Tower',
      variables: {
        name: 'Legacy Tower',
        customerName: 'Mehul',
        client_name: 'Mehul',
        date: '29/10/2026',
        time: '01:57 PM',
        projectName: 'Legacy Tower',
        project: 'Legacy Tower',
        pname: 'Legacy Tower',
      },
    });
    assert(
      capturedBody.includes('templateVariable-name-1=Mehul') ||
        capturedBody.includes('templateVariable-1=Mehul'),
      'Rejects project as name and uses real person name',
    );
    assert(
      !capturedBody.includes('templateVariable-name-1=Legacy') &&
        !capturedBody.includes('templateVariable-1=Legacy'),
      'Does not put Legacy Tower into name/{{1}}',
    );
    assert(
      !capturedBody.includes('template_header_variable-1=Legacy') &&
        !capturedBody.includes('templateHeaderVariable-1=Legacy'),
      'Does not send project name as header variable',
    );
    assert(
      !capturedBody.includes('templateVariable-pname-1=') &&
        !capturedBody.includes('templateVariable-project-1='),
      'Does not dump project vars when template only allows name/date/time',
    );
  }

  // Test 6: Dynamic Variable Resolver (no unresolved placeholders)
  {
    console.log('\nTest Suite 6: Dynamic Variable Resolver');
    const service = new WhatsappService();

    const template =
      'Hi {{customerName}}, your visit for {{projectName}} is on {{siteVisitDate}} at {{siteVisitTime}} with {{salespersonName}}. Pin: {{locationUrl}}';

    const rendered = service.renderTemplate(template, {
      customerName: 'Aarav Patel',
      projectName: 'Legacy Tower',
      siteVisitDate: 'Sat, 12 Oct 2026',
      siteVisitTime: '03:00 PM',
      salespersonName: 'Rahul Verma',
      locationUrl: 'https://maps.google.com/?q=Legacy+Tower',
    });

    assert(
      rendered.includes('Hi Aarav Patel'),
      'Renders {{customerName}} correctly',
    );
    assert(
      rendered.includes('Legacy Tower'),
      'Renders {{projectName}} correctly',
    );
    assert(
      rendered.includes('Sat, 12 Oct 2026'),
      'Renders {{siteVisitDate}} correctly',
    );
    assert(
      rendered.includes('03:00 PM'),
      'Renders {{siteVisitTime}} correctly',
    );
    assert(
      rendered.includes('Rahul Verma'),
      'Renders {{salespersonName}} correctly',
    );
    assert(
      !rendered.includes('{{') && !rendered.includes('}}'),
      'Guarantees NO unresolved {{tags}} remain in message',
    );

    // Fallback test: if variable is missing, customer gets safe fallback rather than raw {{tag}}
    const fallbackRender = service.renderTemplate(
      'Hello {{customerName}}, welcome to {{projectName}}!',
      {},
    );
    assert(
      fallbackRender.includes('Hello Valued Customer'),
      'Provides sensible fallback instead of raw {{placeholder}}',
    );
    assert(
      !fallbackRender.includes('{{customerName}}'),
      'Raw tag is never shown to customer',
    );
  }

  // Test 7: Google Calendar Link Generation
  {
    console.log('\nTest Suite 7: Google Calendar URL Builder');
    const calUrl = WhatsappService.buildGoogleCalendarUrl({
      title: 'Site Visit - Legacy Tower',
      details: 'Confirmed site visit',
      location: 'Legacy Tower, Ahmedabad',
      dateStr: '2026-10-15',
      timeStr: '02:30 PM',
    });

    assert(
      calUrl.startsWith('https://calendar.google.com/calendar/render?action=TEMPLATE'),
      'Builds valid Google Calendar Template URL',
    );
    assert(
      calUrl.includes('Site+Visit+-+Legacy+Tower'),
      'Encodes calendar event title correctly',
    );
  }

  // Restore fetch
  global.fetch = originalFetch;

  console.log(`\n========================================`);
  console.log(`Results: ${passed} Passed, ${failed} Failed`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
