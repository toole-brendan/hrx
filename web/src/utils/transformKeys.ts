/**
 * Convert a string from snake_case to camelCase
 */
export function snakeToCamel(str: string): string {
  return str.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
}

/**
 * Convert a string from camelCase to snake_case
 */
export function camelToSnake(str: string): string {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
}

/**
 * Transform object keys between naming conventions
 */
export function transformKeys<T = any>(
  obj: any,
  direction: 'snakeToCamel' | 'camelToSnake'
): T {
  if (obj === null || obj === undefined) {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map(item => transformKeys(item, direction)) as any;
  }

  if (typeof obj !== 'object' || obj instanceof Date) {
    return obj;
  }

  const transform = direction === 'snakeToCamel' ? snakeToCamel : camelToSnake;

  const transformed: any = {};
  for (const [key, value] of Object.entries(obj)) {
    const newKey = transform(key);
    transformed[newKey] = transformKeys(value, direction);
  }

  return transformed;
}