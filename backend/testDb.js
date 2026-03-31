const { PrismaClient } = require('@prisma/client');
const fs = require('fs');
const prisma = new PrismaClient();

async function run() {
  const req = await prisma.changeRequest.findFirst({ where: { status: 'PENDING' } });
  if (req) {
    fs.writeFileSync('test.json', JSON.stringify(req.newData, null, 2));
  } else {
    fs.writeFileSync('test.json', 'No pending requests found.');
  }
}

run().finally(() => prisma.$disconnect());
