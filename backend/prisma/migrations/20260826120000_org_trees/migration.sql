-- CreateTable
CREATE TABLE "org_trees" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "grouping" TEXT NOT NULL DEFAULT 'DEPARTMENT_LEAD',
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "snapshot" JSONB NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "org_trees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "org_tree_contacts" (
    "id" TEXT NOT NULL,
    "tree_id" TEXT NOT NULL,
    "module_key" TEXT NOT NULL,
    "module_name" TEXT NOT NULL,
    "employee_id" INTEGER,
    "note" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "org_tree_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "org_trees_is_active_idx" ON "org_trees"("is_active");

-- CreateIndex
CREATE UNIQUE INDEX "org_tree_contacts_tree_id_module_key_key" ON "org_tree_contacts"("tree_id", "module_key");

-- AddForeignKey
ALTER TABLE "org_trees" ADD CONSTRAINT "org_trees_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "org_tree_contacts" ADD CONSTRAINT "org_tree_contacts_tree_id_fkey" FOREIGN KEY ("tree_id") REFERENCES "org_trees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "org_tree_contacts" ADD CONSTRAINT "org_tree_contacts_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
