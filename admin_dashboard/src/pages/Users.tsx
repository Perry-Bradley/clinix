import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';

interface User {
  id: string;
  name: string;
  email: string;
  type: 'patient' | 'provider';
  registered: string;
}

const mockFetchUsers = async (): Promise<User[]> => {
  return [
    { id: '1', name: 'John Doe', email: 'john@example.com', type: 'patient', registered: '2025-01-10' },
    { id: '2', name: 'Dr. Jane Smith', email: 'jane@clinic.cm', type: 'provider', registered: '2025-01-12' },
    { id: '3', name: 'Alice Ngwa', email: 'alice@example.cm', type: 'patient', registered: '2025-02-08' },
    { id: '4', name: 'Dr. Paul Biya', email: 'paul@doctors.cm', type: 'provider', registered: '2025-02-20' },
  ];
};

const Users = () => {
  const [filter, setFilter] = useState<'all' | 'patient' | 'provider'>('all');
  const { data: users, isLoading } = useQuery<User[]>({
    queryKey: ['users'],
    queryFn: mockFetchUsers,
  });

  if (isLoading) return <div className="p-4 text-gray-500">Loading users...</div>;

  const filtered = filter === 'all' ? users : users?.filter((u) => u.type === filter);

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">User Management</h2>
        <select
          className="border border-gray-300 rounded-lg px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
          value={filter}
          onChange={(e) => setFilter(e.target.value as typeof filter)}
        >
          <option value="all">All Users</option>
          <option value="patient">Patients</option>
          <option value="provider">Providers</option>
        </select>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              {['Name', 'Email', 'Type', 'Registered', 'Actions'].map((col) => (
                <th
                  key={col}
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {filtered?.map((user: User) => (
              <tr key={user.id} className="hover:bg-gray-50 transition">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-3">
                    <div className="w-8 h-8 rounded-full bg-teal-100 flex items-center justify-center text-teal-600 font-semibold text-sm">
                      {user.name[0]}
                    </div>
                    <span className="text-sm font-medium text-gray-900">{user.name}</span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{user.email}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span
                    className={`px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full ${
                      user.type === 'provider'
                        ? 'bg-green-100 text-green-800'
                        : 'bg-blue-100 text-blue-800'
                    }`}
                  >
                    {user.type}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{user.registered}</td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <button className="text-teal-600 hover:text-teal-900 font-medium">Suspend</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Users;
