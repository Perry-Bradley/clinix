import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { UserPlus, Edit2, ShieldAlert, Trash2 } from 'lucide-react';
import ProviderFormModal from '../components/ProviderFormModal';

interface User {
  id: string;
  name: string;
  email: string;
  type: 'patient' | 'provider';
  registered: string;
  spec?: string;
  license?: string;
  bio?: string;
}

const mockFetchUsers = async (): Promise<User[]> => {
  return [
    { id: '1', name: 'John Doe', email: 'john@example.com', type: 'patient', registered: '2025-01-10' },
    { id: '2', name: 'Dr. Jane Smith', email: 'jane@clinic.cm', type: 'provider', registered: '2025-01-12', spec: 'Cardiologist', license: 'CM-001', bio: 'Expert in heart surgery.' },
    { id: '3', name: 'Alice Ngwa', email: 'alice@example.cm', type: 'patient', registered: '2025-02-08' },
    { id: '4', name: 'Dr. Paul Biya', email: 'paul@doctors.cm', type: 'provider', registered: '2025-02-20', spec: 'Neurologist', license: 'CM-003', bio: 'Specialist in brain disorders.' },
  ];
};

const Users = () => {
  const [filter, setFilter] = useState<'all' | 'patient' | 'provider'>('all');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  const { data: users, isLoading } = useQuery<User[]>({
    queryKey: ['users'],
    queryFn: mockFetchUsers,
  });

  if (isLoading) return <div className="p-4 text-gray-500">Loading users...</div>;

  const filtered = filter === 'all' ? users : users?.filter((u) => u.type === filter);

  const handleCreate = () => {
    setSelectedUser(null);
    setIsModalOpen(true);
  };

  const handleEdit = (user: User) => {
    setSelectedUser(user);
    setIsModalOpen(true);
  };

  const handleSubmit = (data: any) => {
    console.log('Submit:', data);
    alert(`Success! Provider ${data.name} ${selectedUser ? 'updated' : 'registered'}.`);
    setIsModalOpen(false);
  };

  const handleSuspend = (name: string) => {
    if (confirm(`Are you sure you want to suspend access for ${name}?`)) {
      alert(`${name} has been suspended.`);
    }
  };

  return (
    <div>
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8 gap-4">
        <div>
          <h2 className="text-2xl font-bold text-dark-900 leading-tight">User Directory</h2>
          <p className="text-gray-400 text-sm">Manage patients and healthcare providers</p>
        </div>
        
        <div className="flex items-center space-x-3 w-full sm:w-auto">
          <select
            className="border border-gray-200 rounded-xl px-4 py-2.5 text-sm font-medium bg-white focus:outline-none focus:ring-2 focus:ring-teal-400/20 transition-all cursor-pointer shadow-sm"
            value={filter}
            onChange={(e) => setFilter(e.target.value as typeof filter)}
          >
            <option value="all">Mixed Roles</option>
            <option value="patient">Patients Only</option>
            <option value="provider">Providers Only</option>
          </select>
          
          <button 
            onClick={handleCreate}
            className="flex items-center space-x-2 px-5 py-2.5 bg-teal-600 text-white rounded-xl shadow-lg shadow-teal-600/20 hover:bg-teal-700 transition-all text-sm font-bold"
          >
            <UserPlus size={18} />
            <span>Register Provider</span>
          </button>
        </div>
      </div>

      <div className="bg-white rounded-3xl shadow-xl shadow-gray-200/50 border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-100">
            <thead className="bg-gray-50/50">
              <tr>
                {['Name & Identity', 'Email Address', 'Type', 'Registration Date', 'Actions'].map((col) => (
                  <th
                    key={col}
                    className="px-8 py-5 text-left text-[10px] font-bold text-gray-400 uppercase tracking-widest"
                  >
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
              {filtered?.map((user: User) => (
                <tr key={user.id} className="group hover:bg-teal-50/30 transition-colors">
                  <td className="px-8 py-5 whitespace-nowrap">
                    <div className="flex items-center space-x-4">
                      <div className="w-10 h-10 rounded-2xl bg-teal-600 flex items-center justify-center text-white font-bold text-sm shadow-sm shadow-teal-600/20 group-hover:scale-105 transition-transform">
                        {user.name[0]}
                      </div>
                      <div>
                        <p className="text-sm font-bold text-dark-900 group-hover:text-teal-700 transition-colors">{user.name}</p>
                        <p className="text-[10px] font-mono text-gray-400 uppercase tracking-tighter">ID: {user.id.padStart(4, '0')}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-8 py-5 whitespace-nowrap text-sm text-gray-500 font-medium">{user.email}</td>
                  <td className="px-8 py-5 whitespace-nowrap">
                    <span
                      className={`px-3 py-1 inline-flex text-[10px] leading-5 font-bold rounded-lg uppercase tracking-wider ${
                        user.type === 'provider'
                          ? 'bg-teal-100 text-teal-800'
                          : 'bg-sky-100 text-sky-800'
                      }`}
                    >
                      {user.type}
                    </span>
                  </td>
                  <td className="px-8 py-5 whitespace-nowrap text-sm text-gray-500 font-medium">
                    {new Date(user.registered).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
                  </td>
                  <td className="px-8 py-5 whitespace-nowrap">
                    <div className="flex items-center space-x-2">
                      <button 
                         onClick={() => handleEdit(user)}
                         disabled={user.type !== 'provider'}
                         className="p-2 text-gray-400 hover:text-teal-600 hover:bg-teal-50 rounded-xl transition-all disabled:opacity-0"
                      >
                        <Edit2 size={16} />
                      </button>
                      <button 
                        onClick={() => handleSuspend(user.name)}
                        className="p-2 text-gray-400 hover:text-orange-500 hover:bg-orange-50 rounded-xl transition-all"
                      >
                        <ShieldAlert size={16} />
                      </button>
                      <button className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all">
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filtered?.length === 0 && (
          <div className="p-20 text-center">
            <div className="w-16 h-16 bg-gray-50 rounded-3xl flex items-center justify-center mx-auto mb-4 border border-gray-100 text-gray-300">
               <ShieldAlert size={32} />
            </div>
            <p className="text-gray-400 font-medium">No records found matching your selection.</p>
          </div>
        )}
      </div>

      <ProviderFormModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSubmit={handleSubmit}
        initialData={selectedUser}
      />
    </div>
  );
};

export default Users;
