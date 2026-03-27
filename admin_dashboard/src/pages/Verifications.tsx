import { useQuery } from '@tanstack/react-query';
import { Check, X, Eye } from 'lucide-react';

interface VerificationRequest {
  id: string;
  name: string;
  spec: string;
  submitted: string;
  license: string;
}

const mockFetchVerifications = async (): Promise<VerificationRequest[]> => {
  return [
    { id: 'prov-123', name: 'Dr. John Doe', spec: 'Cardiologist', submitted: '2025-01-20', license: 'CM-MED-001' },
    { id: 'prov-456', name: 'Dr. Mary Jane', spec: 'Pediatrician', submitted: '2025-01-21', license: 'CM-MED-002' },
    { id: 'prov-789', name: 'Dr. Paul Biya', spec: 'Neurologist', submitted: '2025-01-25', license: 'CM-MED-003' },
  ];
};

const Verifications = () => {
  const { data: requests, isLoading } = useQuery<VerificationRequest[]>({
    queryKey: ['verifications'],
    queryFn: mockFetchVerifications,
  });

  if (isLoading) return <div className="p-4 text-gray-500">Loading verifications...</div>;

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">Provider Verifications</h2>
        <span className="bg-orange-100 text-orange-700 text-sm font-semibold px-3 py-1 rounded-full">
          {requests?.length} Pending
        </span>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              {['Provider Name', 'Specialization', 'License No.', 'Submitted', 'Actions'].map((col) => (
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
            {requests?.map((req: VerificationRequest) => (
              <tr key={req.id} className="hover:bg-gray-50 transition">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-3">
                    <div className="w-8 h-8 rounded-full bg-teal-600 flex items-center justify-center text-white text-sm font-semibold">
                      {req.name.split(' ')[1]?.[0]}
                    </div>
                    <span className="text-sm font-medium text-gray-900">{req.name}</span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{req.spec}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="text-xs font-mono bg-gray-100 px-2 py-1 rounded">{req.license}</span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{req.submitted}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-2">
                    <button className="flex items-center space-x-1 px-3 py-1.5 bg-gray-100 text-gray-600 hover:bg-gray-200 rounded-lg transition text-xs font-medium">
                      <Eye size={13} />
                      <span>Review</span>
                    </button>
                    <button className="flex items-center space-x-1 px-3 py-1.5 bg-teal-50 text-teal-600 hover:bg-teal-100 rounded-lg transition text-xs font-medium">
                      <Check size={13} />
                      <span>Approve</span>
                    </button>
                    <button className="flex items-center space-x-1 px-3 py-1.5 bg-red-50 text-red-600 hover:bg-red-100 rounded-lg transition text-xs font-medium">
                      <X size={13} />
                      <span>Reject</span>
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {requests?.length === 0 && (
          <div className="p-12 text-center text-gray-400">
            <UserCheck className="mx-auto mb-3 opacity-40" size={40} />
            <p>No pending verifications at this time.</p>
          </div>
        )}
      </div>
    </div>
  );
};

// local helper for empty state
const UserCheck = ({ size, className }: { size: number; className?: string }) => (
  <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
    <polyline points="16 11 18 13 22 9" />
  </svg>
);

export default Verifications;
