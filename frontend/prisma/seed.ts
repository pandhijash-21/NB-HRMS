import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('Clearing old data...')
  await prisma.auditLog.deleteMany()
  await prisma.academicQualification.deleteMany()
  await prisma.familyMember.deleteMany()
  await prisma.employeeBankInfo.deleteMany()
  await prisma.employeeSalaryInfo.deleteMany()
  await prisma.employeeOtherInfo.deleteMany()
  await prisma.employeeAddress.deleteMany()
  await prisma.employeePersonalInfo.deleteMany()
  await prisma.employeeGeneralInfo.deleteMany()
  await prisma.employee.deleteMany()

  console.log('Seeding dummy employee...')
  const employee = await prisma.employee.upsert({
    where: { id: 1 },
    update: {},
    create: {
      id: 1,
      userId: 'test-user-id',
      status: 'ACTIVE',
      photoUrl: 'https://i.pravatar.cc/300',
      generalInfo: {
        create: {
          fullName: 'DR. JOHN DOE',
          originalJoiningDate: new Date('2014-06-11T00:00:00.000Z'),
          joiningDate: new Date('2014-06-11T00:00:00.000Z'),
          organization: 'GANDHINAGAR UNIVERSITY',
          subOrganization: 'GANDHINAGAR INSTITUTE OF TECHNOLOGY',
          department: 'COMPUTER ENGINEERING',
          functionalDepartment: 'COMPUTER ENGINEERING',
          employeeCategory: 'TEACHING',
          designation: 'PROFESSOR',
          appointmentType: 'FULL_TIME_REGULAR',
          shift: 'GENERAL',
          firstReporting: 'DR. SMITH',
          secondReporting: 'DR. WILLIAMS',
          incrementMonth: 'July',
        }
      },
      personalInfo: {
        create: {
          birthDate: new Date('1980-05-27T00:00:00.000Z'),
          birthPlace: 'AHMEDABAD',
          homeTown: 'AHMEDABAD',
          gender: 'MALE',
          maritalStatus: 'MARRIED',
          nationality: 'INDIAN',
          motherTongue: 'GUJARATI',
          nomineeName: 'JANE DOE',
          nomineeRelation: 'WIFE',
          bloodGroup: 'O_POS',
          passportNo: 'A1234567',
          passportIssuePlace: 'AHMEDABAD',
        }
      },
      salaryInfo: {
        create: {
          payCommission: '7TH PAY',
          payGrade: '10000',
          basicSalary: 144200.00,
        }
      },
      bankInfo: {
        create: {
          bankName: 'STATE BANK OF INDIA',
          bankAccountNo: 'XXXXXXXX1234',
        }
      },
      otherInfo: {
        create: {
          skillSet: 'React, Node, Prisma, Nextjs',
          strength: 'HARD WORKING',
          weakness: 'PERFECTIONIST',
          isHandicapped: false,
          hobbies: 'CRICKET, MUSIC',
          heightInFeet: 5.8
        }
      },
      addresses: {
        create: [
          {
            addressType: 'LOCAL',
            flatBlockNo: 'A-404',
            buildingSociety: 'DEVBHUMI APTS',
            area: 'NAVRANGPURA',
            city: 'AHMEDABAD',
            state: 'GUJARAT',
            country: 'INDIA',
            zipPostalCode: '380009',
            personalEmail: 'johndoe@gmail.com',
            instituteEmail: 'john.doe@gandhinagaruni.ac.in',
            mobileNo: '9904405900'
          },
          {
            addressType: 'PERMANENT',
            flatBlockNo: 'B-12',
            buildingSociety: 'SHANTIVAN',
            area: 'PALDI',
            city: 'AHMEDABAD',
            state: 'GUJARAT',
            country: 'INDIA',
            zipPostalCode: '380007',
          }
        ]
      }
    }
  })

  console.log('Created dummy employee ID: ', employee.id)
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
