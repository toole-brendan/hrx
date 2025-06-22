import { Property } from '@/types';

const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

/**
 * Converts backend property format to frontend Property format
 */
function mapPropertyToProperty(property: any): Property {
  return {
    id: property.id.toString(),
    name: property.name,
    serialNumber: property.serial_number,
    status: property.current_status as Property['status'],
    description: property.description || '',
    category: property.category || 'other',
    location: property.location || '',
    assignedDate: property.assigned_date || new Date().toISOString(),
    components: property.components || [],
    isComponent: property.is_component || false,
    parentItemId: property.parent_item_id,
    nsn: property.nsn,
    assignedTo: property.assigned_to_user_id?.toString(),
    lastInventoryDate: property.last_inventory_date || property.last_verified_at,
    isSensitive: property.is_sensitive_item || false,
  };
}

/**
 * Get authentication headers
 */
function getAuthHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
  };
}

/**
 * Fetch all properties
 */
export async function fetchProperties(): Promise<Property[]> {
  const response = await fetch(`${API_BASE_URL}/property`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  
  if (!response.ok) {
    throw new Error(`Failed to fetch properties: ${response.statusText}`);
  }
  
  const data = await response.json();
  return (data.properties || []).map(mapPropertyToProperty);
}

/**
 * Fetch properties for a specific user
 */
export async function fetchUserProperties(userId: number): Promise<Property[]> {
  const response = await fetch(`${API_BASE_URL}/property/user/${userId}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  
  if (!response.ok) {
    throw new Error(`Failed to fetch user properties: ${response.statusText}`);
  }
  
  const data = await response.json();
  return (data.properties || []).map(mapPropertyToProperty);
}

/**
 * Create a new property
 */
export async function createProperty(property: Partial<Property>): Promise<Property> {
  const response = await fetch(`${API_BASE_URL}/property`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({
      name: property.name,
      serial_number: property.serialNumber,
      description: property.description,
      category: property.category,
      location: property.location,
      nsn: property.nsn,
      current_status: property.status || 'Operational',
    }),
  });
  
  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || `Failed to create property: ${response.statusText}`);
  }
  
  const data = await response.json();
  return mapPropertyToProperty(data.property);
}

/**
 * Update property status
 */
export async function updatePropertyStatus(id: string, status: string): Promise<Property> {
  const response = await fetch(`${API_BASE_URL}/property/${id}/status`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ status }),
  });
  
  if (!response.ok) {
    throw new Error(`Failed to update property status: ${response.statusText}`);
  }
  
  const data = await response.json();
  return mapPropertyToProperty(data.property);
}