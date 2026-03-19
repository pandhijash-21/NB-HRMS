import { z } from "zod";

const addressBlockSchema = z.object({
  addressLine1: z.string().min(1, "Address line 1 is required"),
  addressLine2: z.string().optional(),
  city: z.string().min(1, "City is required"),
  district: z.string().optional(),
  state: z.string().min(1, "State is required"),
  pincode: z.string().regex(/^\d{6}$/, "Pincode must be 6 digits"),
  country: z.string().default("India"),
});

export const addressSchema = z.object({
  local: addressBlockSchema,
  permanent: addressBlockSchema,
  sameAsLocal: z.boolean().optional(),
});

export type AddressFormData = z.infer<typeof addressSchema>;
export type AddressBlock = z.infer<typeof addressBlockSchema>;
