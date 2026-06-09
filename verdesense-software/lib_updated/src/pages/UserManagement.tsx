import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, UserPlus, Shield, User } from 'lucide-react';
const users = [
{
  id: 1,
  name: 'John Farmer',
  role: 'Admin',
  email: 'john@verdesense.com'
},
{
  id: 2,
  name: 'Sarah Jenkins',
  role: 'Manager',
  email: 'sarah@verdesense.com'
},
{
  id: 3,
  name: 'Mike Ross',
  role: 'Worker',
  email: 'mike@verdesense.com'
}];

export function UserManagement() {
  const navigate = useNavigate();
  return (
    <div className="p-4 space-y-6">
      <header className="pt-4 pb-2 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button
            onClick={() => navigate(-1)}
            className="w-10 h-10 bg-brand-card border border-brand-border rounded-full shadow-sm flex items-center justify-center text-brand-text hover:bg-brand-border transition-colors">
            
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-2xl font-bold text-brand-text">Team</h1>
        </div>
        <button className="w-10 h-10 bg-brand-primary text-brand-text rounded-full flex items-center justify-center shadow-md hover:brightness-110 transition-colors">
          <UserPlus className="w-5 h-5" />
        </button>
      </header>

      <div className="space-y-3">
        {users.map((user) =>
        <div
          key={user.id}
          className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border flex items-center gap-4">
          
            <div className="w-12 h-12 bg-brand-dark border border-brand-border rounded-full flex items-center justify-center text-brand-muted shrink-0">
              <User className="w-6 h-6" />
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="font-bold text-brand-text truncate">
                {user.name}
              </h3>
              <p className="text-xs text-brand-muted truncate">{user.email}</p>
            </div>
            <div className="flex items-center gap-1 text-xs font-bold text-brand-primary bg-brand-primary/10 border border-brand-primary/20 px-2.5 py-1.5 rounded-full">
              {user.role === 'Admin' && <Shield className="w-3 h-3" />}
              {user.role}
            </div>
          </div>
        )}
      </div>
    </div>);

}