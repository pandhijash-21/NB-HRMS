
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('--- USERS ---');
  const users = await prisma.user.findMany({
    include: {
      role: true,
      employee: {
        include: {
          generalInfo: true
        }
      }
    }
  });
  
  users.forEach(u => {
    console.log(`User ID: ${u.id}, EmployeeID: ${u.employeeId}, Role: ${u.role.name}, Active: ${u.isActive}`);
    console.log(`Full Name: ${u.employee?.generalInfo?.fullName}`);
    console.log(`Password Hash: ${u.passwordHash}`);
    console.log('---');
  });

  console.log('\n--- ALL EMPLOYEES ---');
  const employees = await prisma.employee.findMany({
    include: {
      generalInfo: true
    }
  });
  employees.forEach(e => {
    console.log(`Employee ID: ${e.id}, Name: ${e.generalInfo?.fullName}`);
  });
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
