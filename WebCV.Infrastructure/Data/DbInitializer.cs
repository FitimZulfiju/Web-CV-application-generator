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
                    ProfessionalSummary = "Full-Stack .NET Developer with 7+ years building enterprise web applications and microservices. Specialized in .NET Core, Blazor, ASP.NET Core, and cloud-native architectures. Proven track record delivering scalable solutions for transportation, document processing, and ERP systems across consulting and product companies. Strong expertise in API design, system integration, and Agile development.",
                    Skills =
                    [
                        new Skill { Name = ".NET 8/9", Category = "Backend" },
                    new Skill { Name = "ASP.NET Core", Category = "Backend" },
                    new Skill { Name = "C#", Category = "Backend" },
                    new Skill { Name = "Entity Framework Core", Category = "Backend" },
                    new Skill { Name = "ADO.NET", Category = "Backend" },
                    new Skill { Name = "Microservices Architecture", Category = "Backend" },
                    new Skill { Name = "REST API", Category = "Backend" },
                    new Skill { Name = "GraphQL", Category = "Backend" },

                    new Skill { Name = "Blazor (Server/WebAssembly)", Category = "Frontend" },
                    new Skill { Name = "Angular", Category = "Frontend" },
                    new Skill { Name = "HTML5", Category = "Frontend" },
                    new Skill { Name = "CSS3", Category = "Frontend" },
                    new Skill { Name = "JavaScript", Category = "Frontend" },
                    new Skill { Name = "TypeScript", Category = "Frontend" },
                    new Skill { Name = "MudBlazor", Category = "Frontend" },

                    new Skill { Name = "SQL Server", Category = "Database" },
                    new Skill { Name = "Azure SQL Database", Category = "Database" },
                    new Skill { Name = "Database Design", Category = "Database" },
                    new Skill { Name = "Data Pipelines", Category = "Database" },

                    new Skill { Name = "Docker", Category = "DevOps" },
                    new Skill { Name = "Kubernetes", Category = "DevOps" },
                    new Skill { Name = "Azure DevOps", Category = "DevOps" },
                    new Skill { Name = "Git", Category = "DevOps" },
                    new Skill { Name = "GitHub", Category = "DevOps" },
                    new Skill { Name = "CI/CD Pipelines", Category = "DevOps" },

                    new Skill { Name = "Clean Architecture", Category = "Architecture" },
                    new Skill { Name = "System Integration", Category = "Architecture" },

                    new Skill { Name = "Azure", Category = "Cloud" },
                    new Skill { Name = "OAuth 2.0", Category = "Cloud" },
                    new Skill { Name = "SignalR", Category = "Cloud" }
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
                        Description = "Developed and maintained 25+ Blazor components for enterprise transportation system. Integrated with 1500+ REST API endpoints. Optimized frontend performance reducing load times by 30%. Fixed 35+ critical bugs."
                    },
                    new Experience
                    {
                        CompanyName = "Boyum IT Solutions A/S",
                        JobTitle = "Software Engineer",
                        StartDate = new DateTime(2023, 7, 1),
                        EndDate = new DateTime(2024, 7, 1),
                        IsCurrentRole = false,
                        Location = "København, Denmark",
                        Description = "Architected microservices-based Intelligent Document Processing system. Built full-stack web application using Blazor and GraphQL. Implemented OCR and AI-powered document classification. Designed 15+ RESTful APIs."
                    },
                    new Experience
                    {
                        CompanyName = "ECIT Consulting",
                        JobTitle = "Software Developer",
                        StartDate = new DateTime(2022, 6, 1),
                        EndDate = new DateTime(2023, 6, 1),
                        IsCurrentRole = false,
                        Location = "Herlev, Denmark",
                        Description = "Engineered Visma Business Solutions integrations for 8 clients. Developed Magento-Visma e-commerce connector. Built automated PDF report generator. Implemented DHL Express booking system."
                    },
                    new Experience
                    {
                        CompanyName = "IT Optimiser",
                        JobTitle = "Software Developer",
                        StartDate = new DateTime(2021, 12, 1),
                        EndDate = new DateTime(2022, 5, 1),
                        IsCurrentRole = false,
                        Location = "Skanderborg, Denmark",
                        Description = "Developed AI-powered recruitment matching system analyzing 10,000+ CVs. Built search algorithms matching candidates to job postings. Designed solution using Azure SQL Database."
                    },
                    new Experience
                    {
                        CompanyName = "BK Software Services GmbH",
                        JobTitle = ".NET Programmer & .NET Framework",
                        StartDate = new DateTime(2016, 9, 1),
                        EndDate = new DateTime(2020, 12, 1),
                        IsCurrentRole = false,
                        Location = "Brütten, Switzerland",
                        Description = "Worked as external .NET developer on various client projects. Developed ASP.NET MVC web applications and DNN CMS solutions. Maintained existing .NET Framework applications."
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
                        Description = "**Danish Ministry Recognition:** Equivalent to Danish Bachelor's degree in Computer Science\n(Reference: 17/050244Q, Danish Ministry of Higher Education and Research)"
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
                        Description = "Full-stack ERP solution for retail/inventory management with sales, purchases, invoice generation, email campaigns, automated backups, customers, suppliers, and comprehensive reporting. Modular architecture with 5 projects (API, Server, Client, Components, Shared) following Clean Architecture principles. 65+ secured REST API endpoints with role-based access control. Multi-language support with real-time SignalR notifications. Automated Google Drive backup integration.",
                        Technologies = ".NET 9, Blazor Server, MudBlazor, Entity Framework Core, SQL Server, Docker, SignalR",
                        Link = "Private Repository"
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
