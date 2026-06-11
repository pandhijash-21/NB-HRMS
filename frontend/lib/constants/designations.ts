export const DESIGNATIONS = [
  "Principal/Director",
  "Professor",
  "Associate Professor",
  "Assistant Professor",
  "Lecturer",
  "Teaching Assistant",
  "Librarian",
  "Assistant Librarian",
  "Administrative Officer",
  "Office Superintendent",
  "Account Officer",
  "Head Clers",
  "Senior Clerk/Senior Assistant",
  "Junior Clerk/Junior Assistant",
  "Laboratory Technician",
  "Laboratory Assistant",
  "Laboratory Attendant",
  "Telecaller",
  "Electrician",
  "AC Technician",
  "Peon",
  "Sweeper",
  "Gardner",
] as const;

export type Designation = (typeof DESIGNATIONS)[number];

