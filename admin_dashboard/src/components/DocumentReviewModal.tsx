import React from 'react';
import Modal from './Modal';
import { ExternalLink, FileText, Video, CheckCircle, AlertCircle } from 'lucide-react';

interface Document {
  type: string;
  url: string;
  label: string;
}

interface DocumentReviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  providerName: string;
  documents: Document[];
  onApprove: () => void;
  onReject: () => void;
}

const DocumentReviewModal: React.FC<DocumentReviewModalProps> = ({
  isOpen,
  onClose,
  providerName,
  documents,
  onApprove,
  onReject,
}) => {
  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`Review Documents: ${providerName}`} maxWidth="max-w-4xl">
      <div className="space-y-8">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {documents.map((doc, index) => (
            <div key={index} className="flex flex-col space-y-3 p-4 bg-gray-50 rounded-2xl border border-gray-100">
              <div className="flex items-center justify-between">
                <span className="text-sm font-semibold text-gray-700 flex items-center space-x-2">
                  {doc.type === 'video' ? <Video size={16} /> : <FileText size={16} />}
                  <span>{doc.label}</span>
                </span>
                <a 
                  href={doc.url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-teal-600 hover:text-teal-700 text-xs font-medium flex items-center space-x-1"
                >
                  <span>Open Original</span>
                  <ExternalLink size={12} />
                </a>
              </div>
              
              <div className="aspect-video w-full bg-dark-900 rounded-xl overflow-hidden flex items-center justify-center border border-gray-200 shadow-inner">
                {doc.type === 'image' ? (
                  <img src={doc.url} alt={doc.label} className="w-full h-full object-contain" />
                ) : doc.type === 'video' ? (
                  <video src={doc.url} controls className="w-full h-full" />
                ) : (
                  <div className="text-white text-sm opacity-50">Unsupported Preview</div>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="bg-sky-50 border border-sky-100 p-4 rounded-2xl flex items-start space-x-3">
          <AlertCircle className="text-sky-600 flex-shrink-0 mt-0.5" size={18} />
          <div>
            <h4 className="text-sm font-bold text-sky-800">Verification Checklist</h4>
            <ul className="text-xs text-sky-700 mt-1 space-y-1 list-disc list-inside">
              <li>License number matches the official registry.</li>
              <li>ID card photo matches the facial verification video.</li>
              <li>Documents are current and not expired.</li>
            </ul>
          </div>
        </div>

        <div className="flex items-center justify-end space-x-3 pt-4 border-t border-gray-100">
          <button
            onClick={onReject}
            className="px-6 py-2.5 rounded-xl border border-red-200 text-red-600 font-bold text-sm hover:bg-red-50 transition-colors"
          >
            Reject Application
          </button>
          <button
            onClick={onApprove}
            className="px-6 py-2.5 rounded-xl bg-teal-600 text-white font-bold text-sm hover:bg-teal-700 shadow-lg shadow-teal-600/20 transition-all flex items-center space-x-2"
          >
            <CheckCircle size={18} />
            <span>Approve Provider</span>
          </button>
        </div>
      </div>
    </Modal>
  );
};

export default DocumentReviewModal;
