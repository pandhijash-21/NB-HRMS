import dotenv from 'dotenv';
dotenv.config();

import { whatsappService } from './src/modules/crm/whatsapp.service';

async function test() {
  console.log('--- 1. Testing getRawConfig ---');
  const cfg = await whatsappService.getRawConfig('NB_DEVELOPER');
  console.log('Config:', {
    enabled: cfg.enabled,
    provider: cfg.provider,
    apiBase: cfg.apiBase,
    senderId: cfg.senderId,
    apiKeyLength: cfg.apiKey ? cfg.apiKey.length : 0,
    apiKeyMasked: cfg.apiKey ? cfg.apiKey.slice(0, 4) + '...' + cfg.apiKey.slice(-4) : 'none',
  });

  console.log('\n--- 2. Testing getCachedTemplates ---');
  const templates = await whatsappService.getCachedTemplates('NB_DEVELOPER');
  console.log(`Found ${templates.templates.length} templates:`);
  for (const t of templates.templates) {
    console.log(`- ID: ${t.id}, RawID: ${t.raw?.id}, Name: ${t.name}, Status: ${t.status}, Header: ${t.headerFormat}`);
  }

  console.log('\n--- 3. Testing Test Connection ---');
  const connTest = await whatsappService.testConnection('NB_DEVELOPER');
  console.log('Connection test result:', connTest);

  console.log('\n--- 4. Testing sendDirect (newlead template) to test phone 9638930589 ---');
  const res = await whatsappService.sendDirect({
    phone: '9638930589',
    event: 'TEST',
    messageType: 'TEMPLATE',
    templateId: '463170',
    templateName: 'newlead',
    variables: {
      name: 'Jash',
    },
    scope: 'NB_DEVELOPER',
  });
  console.log('sendDirect result:', JSON.stringify(res, null, 2));

  console.log('\n--- 5. Checking Recent WhatsApp Logs ---');
  const logs = await whatsappService.getLogs(5, 'NB_DEVELOPER');
  console.log('Recent logs:', JSON.stringify(logs, null, 2));
}

test()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test error:', err);
    process.exit(1);
  });
