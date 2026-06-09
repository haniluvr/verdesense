import React from 'react';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer } from
'recharts';
import { TrendingUp, Users, Flame } from 'lucide-react';
const occupancyData = [
{
  time: '08:00',
  count: 2
},
{
  time: '10:00',
  count: 5
},
{
  time: '12:00',
  count: 8
},
{
  time: '14:00',
  count: 6
},
{
  time: '16:00',
  count: 3
},
{
  time: '18:00',
  count: 1
}];

const alertData = [
{
  day: 'Mon',
  alerts: 0
},
{
  day: 'Tue',
  alerts: 1
},
{
  day: 'Wed',
  alerts: 0
},
{
  day: 'Thu',
  alerts: 2
},
{
  day: 'Fri',
  alerts: 0
},
{
  day: 'Sat',
  alerts: 0
},
{
  day: 'Sun',
  alerts: 0
}];

export function Analytics() {
  return (
    <div className="p-4 space-y-6">
      <header className="pt-4 pb-2">
        <h1 className="text-2xl font-bold text-brand-text">Analytics</h1>
        <p className="text-brand-muted text-sm">Farm insights and trends</p>
      </header>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border">
          <div className="flex items-center gap-2 text-brand-primary mb-2">
            <Users className="w-4 h-4" />
            <span className="text-xs font-bold uppercase">Avg Occupancy</span>
          </div>
          <div className="text-2xl font-bold text-brand-text">4.2</div>
          <p className="text-xs text-brand-muted mt-1">People per day</p>
        </div>
        <div className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border">
          <div className="flex items-center gap-2 text-brand-alert mb-2">
            <Flame className="w-4 h-4" />
            <span className="text-xs font-bold uppercase">Total Alerts</span>
          </div>
          <div className="text-2xl font-bold text-brand-text">3</div>
          <p className="text-xs text-brand-muted mt-1">Past 7 days</p>
        </div>
      </div>

      {/* Occupancy Chart */}
      <div className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border">
        <h3 className="font-bold text-brand-text mb-4 flex items-center gap-2">
          <TrendingUp className="w-4 h-4 text-brand-primary" />
          Today's Occupancy
        </h3>
        <div className="h-48 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={occupancyData}>
              <CartesianGrid
                strokeDasharray="3 3"
                vertical={false}
                stroke="#4a2b33" />
              
              <XAxis
                dataKey="time"
                axisLine={false}
                tickLine={false}
                tick={{
                  fontSize: 12,
                  fill: '#a38c91'
                }} />
              
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{
                  fontSize: 12,
                  fill: '#a38c91'
                }} />
              
              <Tooltip
                contentStyle={{
                  borderRadius: '12px',
                  border: '1px solid #4a2b33',
                  backgroundColor: '#2A161A',
                  color: '#f3e8ea'
                }}
                itemStyle={{
                  color: '#f3e8ea'
                }} />
              
              <Line
                type="monotone"
                dataKey="count"
                stroke="#9d5b65"
                strokeWidth={3}
                dot={{
                  r: 4,
                  fill: '#9d5b65',
                  strokeWidth: 2,
                  stroke: '#2A161A'
                }} />
              
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Alerts Chart */}
      <div className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border">
        <h3 className="font-bold text-brand-text mb-4 flex items-center gap-2">
          <Flame className="w-4 h-4 text-brand-alert" />
          Weekly Alerts
        </h3>
        <div className="h-48 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={alertData}>
              <CartesianGrid
                strokeDasharray="3 3"
                vertical={false}
                stroke="#4a2b33" />
              
              <XAxis
                dataKey="day"
                axisLine={false}
                tickLine={false}
                tick={{
                  fontSize: 12,
                  fill: '#a38c91'
                }} />
              
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{
                  fontSize: 12,
                  fill: '#a38c91'
                }}
                allowDecimals={false} />
              
              <Tooltip
                cursor={{
                  fill: '#1A0B0E'
                }}
                contentStyle={{
                  borderRadius: '12px',
                  border: '1px solid #4a2b33',
                  backgroundColor: '#2A161A',
                  color: '#f3e8ea'
                }}
                itemStyle={{
                  color: '#f3e8ea'
                }} />
              
              <Bar dataKey="alerts" fill="#ef4444" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>);

}