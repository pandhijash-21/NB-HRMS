import fs from 'fs';

const client = fs.readFileSync(
  new URL('../src/modules/crm/nineance.client.ts', import.meta.url),
  'utf8',
);

const must = [
  '/api/auth/login/',
  '/api/auth/token/',
  '/api/auth/token/refresh/',
  '/api/auth/signup/',
  '/api/auth/signup/product/',
  '/api/auth/products/',
  '/api/telephony/config/',
  '/api/telephony/config/test/',
  '/api/telephony/provider-configs/',
  '/api/telephony/agents/',
  '/api/telephony/agents/sync/',
  '/api/telephony/agents/bulk-assign/',
  '/api/telephony/agents/me/',
  '/api/telephony/agents/me/status/',
  '/api/telephony/agents/me/softphone-config/',
  '/api/telephony/dids/',
  '/api/telephony/dids/sync/',
  '/api/telephony/calls/click-to-call/',
  '/api/telephony/calls/',
  '/api/telephony/calls/live/',
  '/api/telephony/calls/match/',
  '/api/telephony/dialer/config/',
  '/api/telephony/campaigns/',
  '/api/telephony/campaigns/preview-dial-list/',
  '/api/telephony/dispositions/',
  '/api/telephony/call-groups/',
  '/api/telephony/provider-dashboard/',
  '/api/telephony/analytics/agents/',
  '/api/telephony/analytics/me/',
  '/api/telephony/calls/transcription/capability/',
  '/api/telephony/calls/transcription/settings/',
  '/api/telephony/webhooks/indiavoice/',
];

const templates = [
  'agents/${',
  'dids/${',
  'calls/${',
  'campaigns/${',
  'dispositions/${',
  'provider-configs/${',
  'assign/',
  'bulk-assign/',
  'set-default/',
  '/status/',
  'recording/',
  'disposition/',
  '/start/',
  '/stop/',
  '/report/',
  '/enable/',
];

const missing = must.filter((m) => !client.includes(m));
const missT = templates.filter((t) => !client.includes(t));

console.log('PDF static paths missing from client:', missing.length ? missing : 'NONE');
console.log('Template/path fragments missing:', missT.length ? missT : 'NONE');

const routes = fs.readFileSync(
  new URL('../src/modules/crm/crm.routes.ts', import.meta.url),
  'utf8',
);
const crmMust = [
  "post('/telephony/agents'",
  "delete('/telephony/agents/:id'",
  "post('/telephony/agents/bulk-assign'",
  "get('/telephony/agents/me'",
  "get('/telephony/agents/me/softphone-config'",
  "get('/telephony/webhook-urls'",
  "get('/telephony/provider-configs'",
  "get('/telephony/call-groups'",
  "post('/telephony/dispositions'",
  "put('/telephony/dispositions/:id'",
  "delete('/telephony/dispositions/:id'",
  "get('/telephony/analytics/me'",
  "put('/telephony/config'",
  "get('/telephony/transcription/capability'",
];
const missR = crmMust.filter((m) => !routes.includes(m));
console.log('CRM routes missing:', missR.length ? missR : 'NONE');
