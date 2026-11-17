import { config } from 'dotenv';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { deleteDemoData } from './demo-data.js';

config({ path: '../.env', quiet: true });

async function main() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Refusing to delete demo data when NODE_ENV=production');
  }
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

  const prisma = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
  });
  try {
    await deleteDemoData(prisma);
    console.log('Đã xoá dữ liệu demo (@demo.san7.local và team [DEMO]).');
  } finally {
    await prisma.$disconnect();
  }
}

void main();
