import { prisma } from '../../config/prisma';

function mapDoc(row: {
  id: string;
  title: string;
  description: string | null;
  category: string | null;
  fileUrl: string;
  fileName: string | null;
  mimeType: string | null;
  fileSize: number | null;
  isActive: boolean;
  uploadedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    category: row.category,
    fileUrl: row.fileUrl,
    fileName: row.fileName,
    mimeType: row.mimeType,
    fileSize: row.fileSize,
    isActive: row.isActive,
    uploadedBy: row.uploadedBy,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export const repositoryService = {
  async listActive() {
    const rows = await prisma.companyRepositoryDocument.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map(mapDoc);
  },

  async getById(id: string) {
    const row = await prisma.companyRepositoryDocument.findUnique({ where: { id } });
    if (!row || !row.isActive) throw new Error('Document not found');
    return mapDoc(row);
  },

  async create(input: {
    title: string;
    description?: string | null;
    category?: string | null;
    fileUrl: string;
    fileName?: string | null;
    mimeType?: string | null;
    fileSize?: number | null;
    uploadedBy?: string | null;
  }) {
    const title = input.title.trim();
    if (!title) throw new Error('Title is required');
    if (!input.fileUrl?.trim()) throw new Error('File is required');

    const row = await prisma.companyRepositoryDocument.create({
      data: {
        title,
        description: input.description?.trim() || null,
        category: input.category?.trim() || null,
        fileUrl: input.fileUrl.trim(),
        fileName: input.fileName?.trim() || null,
        mimeType: input.mimeType?.trim() || null,
        fileSize: input.fileSize ?? null,
        uploadedBy: input.uploadedBy ?? null,
      },
    });
    return mapDoc(row);
  },

  async softDelete(id: string) {
    const existing = await prisma.companyRepositoryDocument.findUnique({ where: { id } });
    if (!existing || !existing.isActive) throw new Error('Document not found');
    const row = await prisma.companyRepositoryDocument.update({
      where: { id },
      data: { isActive: false },
    });
    return mapDoc(row);
  },
};
