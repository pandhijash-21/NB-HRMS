/// SystemLookup categories for ERP Agencies (Configurations → Agencies).
const kContractorTds = 'CONTRACTOR_TDS';
const kContractorType = 'CONTRACTOR_TYPE'; // Who are they: Vendor / Contractor / Other
const kContractorAddressType = 'CONTRACTOR_ADDRESS_TYPE';
const kContractorCountry = 'CONTRACTOR_COUNTRY';
const kContractorState = 'CONTRACTOR_STATE';
const kContractorCity = 'CONTRACTOR_CITY';
const kContractorDocumentType = 'CONTRACTOR_DOCUMENT_TYPE';

const kInventoryCategory = 'INVENTORY_CATEGORY';
const kInventoryBrand = 'INVENTORY_BRAND';
const kInventoryUom = 'INVENTORY_UOM';
const kInventorySize = 'INVENTORY_SIZE';
const kPrType = 'PR_TYPE';
const kPrPriority = 'PR_PRIORITY';
const kPaymentTerms = 'PAYMENT_TERMS';

const kContractorLookupKeys = <String>[
  kContractorTds,
  kContractorType,
  kContractorAddressType,
  kContractorCountry,
  kContractorState,
  kContractorCity,
  kContractorDocumentType,
];

const kInventoryLookupKeys = <String>[
  kInventoryCategory,
  kInventoryBrand,
  kInventoryUom,
  kInventorySize,
];

const kPurchaseLookupKeys = <String>[
  kPrType,
  kPrPriority,
  kPaymentTerms,
];
