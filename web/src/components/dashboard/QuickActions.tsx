import React from "react";
import { useLocation } from "wouter";
import { Card, CardContent } from "@/components/ui/card";
import { QrCode, ArrowRightLeft, Search, FileText } from "lucide-react";

interface QuickActionProps {
  icon: React.ReactNode;
  label: string;
  bgColor: string;
  bgGradient: string;
  borderColor: string;
  darkBgGradient: string;
  darkBorderColor: string;
  iconBgColor: string;
  darkIconBgColor: string;
  iconColor: string;
  darkIconColor: string;
  onClick: () => void;
}

const QuickAction: React.FC<QuickActionProps> = ({ 
  icon, 
  label, 
  bgGradient, 
  borderColor, 
  darkBgGradient,
  darkBorderColor,
  iconBgColor,
  darkIconBgColor,
  iconColor,
  darkIconColor,
  onClick 
}) => {
  return (
    <Card 
      className={`${bgGradient} ${darkBgGradient} ${borderColor} ${darkBorderColor} cursor-pointer hover:shadow-md transition-shadow rounded-none`}
      onClick={onClick}
    >
      <CardContent className="p-4 flex items-center justify-between">
        <div>
          <p className="text-sm font-medium">{label}</p>
        </div>
        <div className={`${iconBgColor} ${darkIconBgColor} p-3 rounded-none`}>
          {React.cloneElement(icon as React.ReactElement, { 
            className: `h-5 w-5 ${iconColor} ${darkIconColor}` 
          })}
        </div>
      </CardContent>
    </Card>
  );
};

interface QuickActionsProps {
  openScanner: () => void;
}

const QuickActions: React.FC<QuickActionsProps> = ({ openScanner }) => {
  const [, navigate] = useLocation();

  const actions = [
    { 
      icon: <QrCode />, 
      label: "Scan QR", 
      bgColor: "bg-blue-100",
      bgGradient: "bg-gradient-to-br from-blue-50 to-blue-100",
      borderColor: "border-blue-200",
      darkBgGradient: "dark:from-blue-900/20 dark:to-blue-800/20",
      darkBorderColor: "dark:border-blue-800",
      iconBgColor: "bg-blue-200",
      darkIconBgColor: "dark:bg-blue-700/30",
      iconColor: "text-blue-700",
      darkIconColor: "dark:text-blue-500",
      onClick: openScanner 
    },
    { 
      icon: <ArrowRightLeft />, 
      label: "Request Transfer", 
      bgColor: "bg-amber-100",
      bgGradient: "bg-gradient-to-br from-amber-50 to-amber-100",
      borderColor: "border-amber-200",
      darkBgGradient: "dark:from-amber-900/20 dark:to-amber-800/20",
      darkBorderColor: "dark:border-amber-800",
      iconBgColor: "bg-amber-200",
      darkIconBgColor: "dark:bg-amber-700/30",
      iconColor: "text-amber-700",
      darkIconColor: "dark:text-amber-500",
      onClick: () => navigate("/transfers") 
    },
    { 
      icon: <Search />, 
      label: "Find Item", 
      bgColor: "bg-green-100",
      bgGradient: "bg-gradient-to-br from-green-50 to-green-100",
      borderColor: "border-green-200",
      darkBgGradient: "dark:from-green-900/20 dark:to-green-800/20",
      darkBorderColor: "dark:border-green-800",
      iconBgColor: "bg-green-200",
      darkIconBgColor: "dark:bg-green-700/30",
      iconColor: "text-green-700",
      darkIconColor: "dark:text-green-500",
      onClick: () => navigate("/inventory") 
    },
    { 
      icon: <FileText />, 
      label: "Export Report", 
      bgColor: "bg-red-100",
      bgGradient: "bg-gradient-to-br from-red-50 to-red-100",
      borderColor: "border-red-200",
      darkBgGradient: "dark:from-red-900/20 dark:to-red-800/20",
      darkBorderColor: "dark:border-red-800",
      iconBgColor: "bg-red-200",
      darkIconBgColor: "dark:bg-red-700/30",
      iconColor: "text-red-700",
      darkIconColor: "dark:text-red-500",
      onClick: () => navigate("/audit-log") 
    },
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      {actions.map((action, index) => (
        <QuickAction
          key={index}
          icon={action.icon}
          label={action.label}
          bgColor={action.bgColor}
          bgGradient={action.bgGradient}
          borderColor={action.borderColor}
          darkBgGradient={action.darkBgGradient}
          darkBorderColor={action.darkBorderColor}
          iconBgColor={action.iconBgColor}
          darkIconBgColor={action.darkIconBgColor}
          iconColor={action.iconColor}
          darkIconColor={action.darkIconColor}
          onClick={action.onClick}
        />
      ))}
    </div>
  );
};

export default QuickActions;
