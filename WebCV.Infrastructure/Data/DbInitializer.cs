namespace WebCV.Infrastructure.Data
{
    public static class DbInitializer
    {
        public static async Task InitializeAsync(ApplicationDbContext context, UserManager<User> userManager)
        {
            await context.Database.MigrateAsync();

            // Create default admin user if no users exist
            if (!context.Users.Any())
            {
                var adminUser = new User
                {
                    UserName = "admin@webcv.com",
                    Email = "admin@webcv.com",
                    EmailConfirmed = true
                };

                var result = await userManager.CreateAsync(adminUser, "Admin123!");

                if (!result.Succeeded)
                {
                    throw new Exception($"Failed to create admin user: {string.Join(", ", result.Errors.Select(e => e.Description))}");
                }

                // Get the created user to get the Id
                adminUser = await userManager.FindByEmailAsync("admin@webcv.com");
                if (adminUser == null)
                {
                    throw new Exception("Failed to retrieve created admin user");
                }

                // Look for any profiles.
                if (context.CandidateProfiles.Any())
                {
                    return;   // DB has been seeded
                }

                var profile = new CandidateProfile
                {
                    UserId = adminUser.Id,
                    FullName = "Fitim Zulfiju",
                    Title = "Full-Stack .NET Developer",
                    Email = "fitim.zulfiju@gmail.com",
                    PhoneNumber = "+45 42 47 86 46",
                    LinkedInUrl = "https://linkedin.com/in/fitim-zulfiju-1097724b",
                    PortfolioUrl = "https://github.com/fitimzulfiu",
                    Location = "Copenhagen Area, Denmark",
                    ProfessionalSummary = "Full-Stack .NET Developer with <strong style=color:blue;>7+ years</strong> building enterprise web applications and microservices. Specialized in <strong style=color:blue;>.NET Core, Blazor, ASP.NET Core,</strong> and cloud-native architectures. Proven track record delivering scalable solutions for transportation, document processing, and ERP systems across consulting and product companies. Strong expertise in API design, system integration, and Agile development.",
                    Skills =
                    [
                        new Skill { Name = ".NET 9/10", Category = "Backend Development" },
                        new Skill { Name = "ASP.NET Core", Category = "Backend Development" },
                        new Skill { Name = "C#", Category = "Backend Development" },
                        new Skill { Name = "Entity Framework Core", Category = "Backend Development" },
                        new Skill { Name = "ADO.NET", Category = "Backend Development" },
                        new Skill { Name = "Microservices Architecture", Category = "Backend Development" },
                        new Skill { Name = "REST API", Category = "Backend Development" },
                        new Skill { Name = "GraphQL.", Category = "Backend Development" },

                        new Skill { Name = "Blazor (Server/WebAssembly)", Category = "Frontend Development" },
                        new Skill { Name = "Angular", Category = "Frontend Development" },
                        new Skill { Name = "HTML5", Category = "Frontend Development" },
                        new Skill { Name = "CSS3", Category = "Frontend Development" },
                        new Skill { Name = "JavaScript", Category = "Frontend Development" },
                        new Skill { Name = "TypeScript", Category = "Frontend Development" },
                        new Skill { Name = "MudBlazor.", Category = "Frontend Development" },

                        new Skill { Name = "SQL Server", Category = "Database & Data" },
                        new Skill { Name = "Azure SQL Database", Category = "Database & Data" },
                        new Skill { Name = "Entity Framework Core", Category = "Database & Data" },
                        new Skill { Name = "Database Design", Category = "Database & Data" },
                        new Skill { Name = "Data Pipelines.", Category = "Database & Data" },

                        new Skill { Name = "Docker", Category = "DevOps & Tools" },
                        new Skill { Name = "Kubernetes", Category = "DevOps & Tools" },
                        new Skill { Name = "Azure DevOps", Category = "DevOps & Tools" },
                        new Skill { Name = "Git", Category = "DevOps & Tools" },
                        new Skill { Name = "GitHub", Category = "DevOps & Tools" },
                        new Skill { Name = "CI/CD Pipelines.", Category = "DevOps & Tools" },

                        new Skill { Name = "Microservices", Category = "Architecture & Patterns" },
                        new Skill { Name = "Clean Architecture", Category = "Architecture & Patterns" },
                        new Skill { Name = "API Design", Category = "Architecture & Patterns" },
                        new Skill { Name = "System Integration.", Category = "Architecture & Patterns" },

                        new Skill { Name = "Azure", Category = "Cloud & Integration" },
                        new Skill { Name = "OAuth 2.0", Category = "Cloud & Integration" },
                        new Skill { Name = "SignalR", Category = "Cloud & Integration" },
                        new Skill { Name = "Third-party API Integration (Visma, DHL, Google Drive, Magento).", Category = "Cloud & Integration" }
                    ],
                    WorkExperience =
                    [
                        new Experience
                    {
                        CompanyName = "Uniteam Group",
                        JobTitle = "Software Engineer / Developer",
                        StartDate = new DateTime(2025, 3, 1),
                        EndDate = new DateTime(2025, 8, 1),
                        IsCurrentRole = false,
                        Location = "Taastrup, Denmark",
                        Description = "Developed and maintained <strong style=color:blue;>25+ Blazor components</strong> for enterprise transportation system managing Nordic logistic operations.\n" +
                        "Integrated with <strong style=color:blue;>1500+ REST API endpoints,</strong> implementing 12 new features during 6-month tensure.\n" +
                        "Optimized frontend performance, reducing load times by <strong style=color:blue;>30%</strong> through lazy loading and component caching.\n" +
                        "Fixed <strong style=color:blue;>35+ critical bugs</strong> in legacy codebase while maintaining 100% backward compatibility.\n" +
                        "Collaborated in Agile/Scrum team (8 developers, 3 testers, 2 product owners) using Azure DevOps for sprint planning, code reviews, and CI/CD pipelines."
                    },
                        new Experience
                    {
                        CompanyName = "Boyum IT Solutions A/S",
                        JobTitle = "Software Engineer",
                        StartDate = new DateTime(2023, 7, 1),
                        EndDate = new DateTime(2024, 7, 1),
                        IsCurrentRole = false,
                        Location = "København, Denmark",
                        Description = "Architected microservices-based Intelligent Document Processing system, processing <strong style=color:blue;>10,000+ documents monthly</strong> with 95% accuracy.\n" +
                        "Built full-stack web application using Blazor and GraphQL, reducing API response time by <strong style=color:blue;>60%</strong> compared to tradicional REST.\n" +
                        "Implemented OCR and AI-powered document classification, automating workflows and reducing manual processing time by <strong style=color:blue;>70%.</strong>\n" +
                        "Designed and developed <strong style=color;blue;>15+ RESTful APIs and GraphQL</strong> endpoints for seamless frontend-backend communication.\n" +
                        "Collaborated with cross-functionality Agile team (5 developers, 2 QA engineers) delivering features in 2-week sprints.\n" +
                        "Optimized security implementing OAuth 2.0, JWT authentication, and role-based access control."
                    },
                        new Experience
                    {
                        CompanyName = "ECIT Consulting",
                        JobTitle = "Software Developer",
                        StartDate = new DateTime(2022, 6, 1),
                        EndDate = new DateTime(2023, 6, 1),
                        IsCurrentRole = false,
                        Location = "Herlev, Denmark",
                        Description = "Engineered Visma Business Solutions integrations for <strong style=color;blue;>8 clients,</strong> automating invoicing and inventory management, saving <strong style=color:blue;>100+ hours/month</strong> per client.\n" +
                        "Developed Magento-Visma e-commerce connector synchronizing <strong style=color:blue;>5,000 products</strong> in real time with bi-directional data flow.\n" +
                        "Built automated PDF report generator extracting Visma data, processing images, and emailing reports onscheduled basis.\n" +
                        "Implemented DHL Express booking system with address validation API and automated shiping label generation integrated with Visma.\n" +
                        "Worked independently managing 4-6 concurrent client projects, delivering solutions on time with minimal supervision.\n" +
                        "Gained deep expertise in REST design, third-party integrations, and SQL Server optimization (stored procedures, triggers)."
                    },
                        new Experience
                    {
                        CompanyName = "IT Optimiser",
                        JobTitle = "Software Developer",
                        StartDate = new DateTime(2021, 12, 1),
                        EndDate = new DateTime(2022, 5, 1),
                        IsCurrentRole = false,
                        Location = "Skanderborg, Denmark",
                        Description = "Developed AI-powered recruitment matching system analyzing <strong style:color;blue>10,000+ CVs</strong> using C# and .NET Core.\n" +
                        "Built search algorithms with predefined parameters (skills,experience, location) matching candidates to <strong style:color;blue;>500+ job postings.</strong>\n" +
                        "Designed and implemented solution using Azure SQL Database and Azure Virtual Machine infrastructure.\n" +
                        "Worked independently as sole developer, meeting daily with company owner for requirments and demos."
                    },
                        new Experience
                    {
                        CompanyName = "BK Software Services GmbH",
                        JobTitle = ".NET Programmer & .NET Framework",
                        StartDate = new DateTime(2016, 9, 1),
                        EndDate = new DateTime(2020, 12, 1),
                        IsCurrentRole = false,
                        Location = "Brütten, Switzerland",
                        Description = "Worked as external .NET developer on various client projects for Swiss software services company.\n" +
                        "Developed ASP.NET MVC web applications and DNN CMS solutions.\n" +
                        "Maintained and enhanced existing .NET Framework applications for multiple clients.\n" +
                        "Collaborated remotely across Switzerland and North Macedonia offices."
                    }
                    ],
                    Educations =
                    [
                        new Education
                    {
                        InstitutionName = "SEE University, Tetovo, North Macedonia",
                        Degree = "Bachelor of Computer Science",
                        StartDate = new DateTime(2007, 1, 1),
                        EndDate = new DateTime(2010, 1, 1),
                        Description = "<strong>Danish Ministry Recognition:</strong> " +
                        "Equivalent to Danish Bachelor's degree in Computer Science\n(Reference: 17/050244Q, Danish Ministry of Higher Education and Research)"
                    }
                    ],
                    Projects =
                    [
                        new Project
                    {
                        Name = "MF8 - Enterprise Resource Planning System",
                        Role = "Lead Developer",
                        StartDate = new DateTime(2024, 1, 1),
                        EndDate = new DateTime(2025, 1, 1),
                        Description = "Full-stack ERP solution for retail/inventory management with <strong style=color:blue;>sales, purchases, invoice generation, email campaigns, automated backups,</strong> customers, suppliers, and comprehensive reporting.\n" +
                        "Modular architecture with 5 projects (API, Server, Client, Components, Shared) following Clean Architecture principles.\n" +
                        "<strong style:color:blue;>65+ secured REST API endpoints</strong> with role-based access control (Admin/Manager/User Roles).\n" +
                        "Multi-language support (English/Albanian/Macedonian) with resource localization and real-time SignalR notifications.\n" +
                        "Automated Google Drive backup integration with OAuth 2.0 authentication, scheduling, and Docker contanerization.",
                        Technologies = ".NET 9, Blazor Server, MudBlazor, Entity Framework Core, SQL Server, Docker, SignalR.",
                        Link = "Private Repository (Avaliable upon request)."
                    }
                    ],
                    Languages =
                    [
                        new Language { Name = "Albanian", Proficiency = "Native" },
                        new Language { Name = "English", Proficiency = "Fluent" },
                        new Language { Name = "Macedonian", Proficiency = "Fluent" },
                        new Language { Name = "Croatian", Proficiency = "Conversational" },
                        new Language { Name = "Danish", Proficiency = "Intermediate - Module 3" }
                    ],
                    Interests =
                    [
                        new Interest { Name = "Software Architecture" },
                        new Interest { Name = "AI & Machine Learning" },
                        new Interest { Name = "Cybersecurity" },
                        new Interest { Name = "Blockchain" },
                        new Interest { Name = "Open Source Contribution" },
                        new Interest { Name = "Chess" },
                        new Interest { Name = "Hiking & Cycling" }
                    ]
                };

                context.CandidateProfiles.Add(profile);
                context.SaveChanges();
            }
        }
    }
}
