const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const employeeId = 2; // Assuming employeeId based on previous logs? Or let's just use 2
  const dataToUpdate = {
    "gender": "FEMALE",
    "homeTown": "Gujarat",
    "subCaste": "sindhi",
    "birthDate": "1998-01-01",
    "birthPlace": "Ahmedabad",
    "bloodGroup": null,
    "passportNo": "",
    "nationality": "INDIAN",
    "nomineeName": "",
    "castCategory": "OPEN",
    "customFields": {},
    "motherTongue": "Punjabi",
    "maritalStatus": "MARRIED",
    "nomineeRelation": "",
    "passportIssueDate": null,
    "passportExpiryDate": null,
    "passportIssuePlace": ""
  };
  
  const dateFields = ['birthDate', 'passportIssueDate', 'passportExpiryDate'];
  for (const f of dateFields) {
    if (dataToUpdate[f]) {
      const d = new Date(dataToUpdate[f]);
      if (!isNaN(d.getTime())) {
        dataToUpdate[f] = d;
      } else {
        delete dataToUpdate[f];
      }
    } else {
      delete dataToUpdate[f];
    }
  }

  const allowed = [
    'birthDate', 'birthPlace', 'homeTown', 'gender', 'maritalStatus', 
    'nationality', 'motherTongue', 'bloodGroup', 'castCategory', 'subCaste',
    'nomineeName', 'nomineeRelation', 'passportNo', 'passportIssuePlace',
    'passportIssueDate', 'passportExpiryDate', 'customFields'
  ];
  const filtered = Object.keys(dataToUpdate)
    .filter(key => allowed.includes(key))
    .reduce((obj, key) => { obj[key] = dataToUpdate[key]; return obj; }, {});

  console.log("Filtered payload:", filtered);

  try {
    const res = await prisma.employeePersonalInfo.update({
      where: { employeeId: 2 },
      data: filtered
    });
    console.log("Update SUCCESS", res.id);
  } catch (err) {
    console.error("Update ERROR:", err);
  }
}

run().finally(() => prisma.$disconnect());
