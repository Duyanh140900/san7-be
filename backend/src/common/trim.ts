import { Transform } from 'class-transformer';

/** Cắt khoảng trắng hai đầu TRƯỚC khi validate (ValidationPipe có transform: true). */
export const Trim = () =>
  Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  );
