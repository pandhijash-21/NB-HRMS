"use client";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

interface TabDefinition {
  value: string;
  label: string;
  content: React.ReactNode;
}

interface ProfileTabsProps {
  tabs: TabDefinition[];
  defaultTab?: string;
}

export function ProfileTabs({ tabs, defaultTab }: ProfileTabsProps) {
  return (
    <Tabs defaultValue={defaultTab ?? tabs[0]?.value} className="mt-4">
      <TabsList className="flex flex-wrap h-auto gap-1 bg-slate-100 p-1 rounded-lg">
        {tabs.map((tab) => (
          <TabsTrigger
            key={tab.value}
            value={tab.value}
            className="text-xs data-[state=active]:bg-[#1d3459] data-[state=active]:text-white rounded-md"
          >
            {tab.label}
          </TabsTrigger>
        ))}
      </TabsList>

      {tabs.map((tab) => (
        <TabsContent key={tab.value} value={tab.value} className="mt-4">
          {tab.content}
        </TabsContent>
      ))}
    </Tabs>
  );
}
