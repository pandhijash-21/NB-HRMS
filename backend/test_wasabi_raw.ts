import * as dotenv from 'dotenv';
import * as path from 'path';
dotenv.config({ path: path.join(__dirname, '.env') });
import { PrismaClient } from '@prisma/client';

const p = new PrismaClient();

async function main() {
  const rows = await p.crmSetting.findMany({
    where: { key: { in: ['whatsapp_api_key', 'whatsapp_sender_id', 'whatsapp_api_base'] } }
  });
  const map: Record<string, string> = {};
  rows.forEach(r => map[r.key] = r.value);

  const endpoint = `${map.whatsapp_api_base || 'https://dash.botbiz.io/api/v1'}/whatsapp/send/template`;
  const form = new URLSearchParams();
  form.set('apiToken', map.whatsapp_api_key);
  form.set('phone_number_id', map.whatsapp_sender_id);
  form.set('phone_number', '919638930589');
  form.set('template_id', '463170');
  form.set('template_name', 'newlead');
  form.set('template_header_media_url', 'https://bot-data.s3.ap-southeast-1.wasabisys.com/flowbuilder/306044/306044/whatsapp-440327/flowbuilder-306044-1792663002.pdf');
  form.set('templateVariable-name-1', 'Jash');

  console.log('Sending direct request to BotBiz with Wasabi URL...');
  const t0 = Date.now();
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form.toString()
  });
  const text = await res.text();
  console.log(`Elapsed: ${Date.now() - t0}ms`);
  console.log('Status:', res.status);
  console.log('Body:', text);
}

main().finally(() => p.$disconnect());
