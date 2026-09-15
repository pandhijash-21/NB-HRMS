-- CreateEnum
CREATE TYPE "EarthPropertyKind" AS ENUM (
  'FLAT',
  'APARTMENT',
  'BUNGALOW',
  'VILLA',
  'PENTHOUSE',
  'ROW_HOUSE',
  'DUPLEX',
  'STUDIO',
  'SHOP',
  'OFFICE',
  'WAREHOUSE',
  'SHOWROOM',
  'LAND',
  'PLOT',
  'FARMHOUSE',
  'MIXED_USE',
  'OTHER'
);

-- CreateEnum
CREATE TYPE "EarthPropertyStatus" AS ENUM (
  'AVAILABLE',
  'UNDER_CONSTRUCTION',
  'RESERVED',
  'SOLD',
  'RENTED',
  'HOLD'
);

-- CreateEnum
CREATE TYPE "EarthMediaKind" AS ENUM ('PHOTO', 'DOCUMENT');

-- CreateTable
CREATE TABLE "earth_properties" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "kind" "EarthPropertyKind" NOT NULL,
    "custom_kind" TEXT,
    "status" "EarthPropertyStatus" NOT NULL DEFAULT 'AVAILABLE',
    "latitude" DECIMAL(10,7) NOT NULL,
    "longitude" DECIMAL(10,7) NOT NULL,
    "altitude_m" DECIMAL(10,2),
    "address" TEXT,
    "locality" TEXT,
    "city" TEXT,
    "state" TEXT,
    "country" TEXT,
    "pincode" TEXT,
    "image_url" TEXT,
    "specs" JSONB,
    "carpet_area" DECIMAL(14,2),
    "built_up_area" DECIMAL(14,2),
    "plot_area" DECIMAL(14,2),
    "area_unit" TEXT,
    "bedrooms" INTEGER,
    "bathrooms" INTEGER,
    "floor_no" INTEGER,
    "total_floors" INTEGER,
    "current_price" DECIMAL(16,2),
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "notes" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT,
    "updated_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "earth_properties_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "earth_property_prices" (
    "id" TEXT NOT NULL,
    "property_id" TEXT NOT NULL,
    "amount" DECIMAL(16,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "price_per_area" DECIMAL(16,2),
    "effective_from" TIMESTAMP(3) NOT NULL,
    "effective_to" TIMESTAMP(3),
    "notes" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "earth_property_prices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "earth_property_media" (
    "id" TEXT NOT NULL,
    "property_id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "kind" "EarthMediaKind" NOT NULL DEFAULT 'PHOTO',
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "file_name" TEXT,
    "mime_type" TEXT,
    "file_size" INTEGER,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "earth_property_media_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "earth_properties_is_active_created_at_idx" ON "earth_properties"("is_active", "created_at");

-- CreateIndex
CREATE INDEX "earth_properties_kind_status_idx" ON "earth_properties"("kind", "status");

-- CreateIndex
CREATE INDEX "earth_properties_city_idx" ON "earth_properties"("city");

-- CreateIndex
CREATE INDEX "earth_properties_latitude_longitude_idx" ON "earth_properties"("latitude", "longitude");

-- CreateIndex
CREATE INDEX "earth_property_prices_property_id_effective_from_idx" ON "earth_property_prices"("property_id", "effective_from");

-- CreateIndex
CREATE INDEX "earth_property_prices_effective_from_idx" ON "earth_property_prices"("effective_from");

-- CreateIndex
CREATE INDEX "earth_property_media_property_id_idx" ON "earth_property_media"("property_id");

-- AddForeignKey
ALTER TABLE "earth_property_prices" ADD CONSTRAINT "earth_property_prices_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "earth_properties"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "earth_property_media" ADD CONSTRAINT "earth_property_media_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "earth_properties"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Register admin module
INSERT INTO "system_modules" ("id", "key", "name", "description", "category", "sort_order", "is_active", "created_at")
VALUES (
  gen_random_uuid(),
  'GOOGLE_EARTH',
  'NB Earth',
  '3D globe property inventory, satellite map, price history, and Earth dashboard trends',
  'HRMS',
  17,
  true,
  NOW()
)
ON CONFLICT ("key") DO UPDATE SET
  "name" = EXCLUDED."name",
  "description" = EXCLUDED."description",
  "category" = EXCLUDED."category",
  "sort_order" = EXCLUDED."sort_order",
  "is_active" = true;
