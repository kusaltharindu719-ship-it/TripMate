# TripMate – Project Blueprint

## 1. Project Title

TripMate – Smart Travel Planning and Service Marketplace

---

## 2. Project Overview

TripMate is a web-based travel planning and service marketplace designed to help travelers organize an entire trip through one platform.

The system connects travelers with accommodation providers, restaurants, tourist attractions, activities, and registered drivers.

A traveler can create a trip, select multiple destinations, explore accommodation and restaurant services, add preferred services to a trip cart, calculate route and distance information, request transport, receive bids from drivers, compare available bids, and confirm the most suitable option.

TripMate also includes an AI-assisted trip planner that can provide destination, accommodation, restaurant, activity, and estimated budget suggestions based on traveler requirements.

---

## 3. Main Objectives

The main objectives of TripMate are to:

- Provide a complete travel planning platform.
- Allow travelers to manage multiple destinations in one trip.
- Connect travelers with restaurants and accommodation providers.
- Allow drivers to bid for traveler transport requests.
- Provide route and distance information before transport bidding.
- Support trip cart and booking management.
- Provide ratings and reviews.
- Support AI-assisted travel recommendations.
- Provide secure role-based access for different system users.

---

## 4. Main User Roles

### 4.1 Traveler

The traveler is the main user of TripMate.

A traveler can:

- Register and log in.
- Manage personal profile information.
- Create trips.
- Select a starting location.
- Select multiple destinations.
- Enter trip dates.
- Enter number of travelers.
- Define a budget.
- Select travel preferences.
- Browse accommodation.
- Compare rooms and facilities.
- Browse restaurants.
- View food items and buffet packages.
- View restaurant services and facilities.
- Browse attractions and activities.
- Add services to the Trip Cart.
- View estimated trip costs.
- Create a transport request.
- Receive driver bids.
- Compare driver bids.
- Select a driver.
- Follow trip progress.
- Manage bookings.
- Submit ratings and reviews.
- Use the AI Trip Planner.

---

### 4.2 Restaurant Owner

Restaurant owners can:

- Register as a restaurant service provider.
- Create and update restaurant profiles.
- Add restaurant contact information.
- Add location information.
- Add opening hours.
- Add restaurant images.
- Define cuisine types.
- Define service modes such as:
  - Dine-in
  - Takeaway
  - Delivery
  - Pickup
- Define restaurant facilities.
- Define restaurant policies such as BYOB.
- Manage food categories.
- Add food items.
- Update food prices.
- Update food availability.
- Create buffet packages.
- Define food included in buffet packages.
- Create offers and promotions.
- Manage temporary closures and availability.
- Manage restaurant reservations.

---

### 4.3 Accommodation Owner

Accommodation providers can:

- Register as an accommodation provider.
- Add properties.
- Manage property details.
- Add accommodation images.
- Define accommodation type.
- Add room types.
- Define room capacity.
- Define beds and room facilities.
- Set room prices.
- Define property amenities.
- Define meal plans.
- Manage room availability.
- Define check-in and check-out information.
- Add special offers.
- Manage accommodation bookings.

Possible accommodation types include:

- Hotel
- Resort
- Villa
- Guest House
- Apartment
- Hostel
- Homestay

---

### 4.4 Driver

Drivers can:

- Register as drivers.
- Manage driver profiles.
- Add driving licence information.
- Add vehicles.
- Define vehicle type.
- Define passenger capacity.
- Define luggage capacity.
- Update availability.
- View available trip requests.
- View pickup locations.
- View selected destinations.
- View approximate route distance.
- View trip dates.
- View passenger requirements.
- Submit transport bids.
- Update or withdraw eligible bids.
- View accepted trips.
- Update trip progress.

---

### 4.5 Administrator

Administrators can:

- Manage users.
- Manage service providers.
- Verify drivers.
- Verify accommodation providers.
- Verify restaurant providers.
- Manage reported content.
- Monitor trips and bookings.
- Manage complaints.
- View system reports and statistics.
- Manage system-level reference data.

---

## 5. Main System Modules

TripMate contains the following main modules:

1. Authentication and User Management
2. Traveler Profile Management
3. Trip Planning
4. Destination Management
5. Restaurant Marketplace
6. Accommodation Marketplace
7. Attractions and Activities
8. Trip Cart
9. Maps and Location Services
10. Driver Management
11. Transport Request Management
12. Driver Bidding
13. Booking Management
14. Ratings and Reviews
15. Notification Management
16. AI Trip Planner
17. Administration

---

## 6. Traveler Trip Workflow

Traveler Login
↓
Traveler Dashboard
↓
Create New Trip
↓
Enter Starting Location
↓
Enter Trip Dates
↓
Enter Number of Travelers
↓
Enter Budget and Preferences
↓
Select Destinations
↓
Calculate Route and Distance
↓
Browse Accommodation
↓
Select Room
↓
Add to Trip Cart
↓
Browse Restaurants
↓
Select Food / Buffet / Restaurant Service
↓
Add to Trip Cart
↓
Browse Attractions and Activities
↓
Add Activities to Trip
↓
Review Trip Cart
↓
View Estimated Budget
↓
Create Transport Request
↓
Drivers View Trip Request
↓
Drivers Submit Bids
↓
Traveler Compares Bids
↓
Traveler Selects Driver
↓
Confirm Trip
↓
Trip Becomes Ongoing
↓
Complete Trip
↓
Submit Ratings and Reviews

---

## 7. Restaurant Module Design

Restaurant information will include:

### Restaurant Profile

- Name
- Description
- Address
- Latitude
- Longitude
- Phone
- Email
- Price range
- Active status

### Opening Hours

Opening hours will be stored separately for each day of the week.

### Restaurant Service Modes

Examples:

- Dine-in
- Takeaway
- Delivery
- Pickup

### Restaurant Features

Examples:

- Parking
- Wi-Fi
- Air Conditioning
- Outdoor Seating
- Rooftop Seating
- Wheelchair Access
- Live Music
- Kids Menu
- Family Friendly
- Smoking Area
- Non-Smoking Area
- BYOB
- Card Payments
- Digital Payments

### Cuisine Types

Examples:

- Sri Lankan
- Indian
- Chinese
- Italian
- Japanese
- Thai
- Seafood
- International

### Food Management

Restaurants can manage:

- Food Categories
- Food Items
- Descriptions
- Prices
- Images
- Availability

### Buffet Management

Restaurants can manage:

- Buffet Name
- Description
- Price Per Person
- Included Items
- Start Time
- End Time
- Availability

### Restaurant Offers

Restaurants can create:

- Percentage Discounts
- Fixed Discounts
- Special Meal Offers
- Buffet Offers
- Limited-Time Promotions

---

## 8. Accommodation Module Design

Accommodation information will include:

### Property Information

- Property Name
- Description
- Address
- Location
- Property Type
- Contact Information
- Check-in Time
- Check-out Time
- Images

### Amenities

Examples:

- Parking
- Wi-Fi
- Swimming Pool
- Air Conditioning
- Restaurant
- Gym
- Spa
- Airport Transfer
- Room Service
- Laundry
- Wheelchair Access

### Room Information

Each room type can contain:

- Room Name
- Room Type
- Description
- Number of Beds
- Bed Types
- Maximum Guests
- Price Per Night
- Available Room Count
- Room Images
- Room Facilities

### Meal Plans

Examples:

- Room Only
- Breakfast Included
- Half Board
- Full Board

### Availability

Room availability will be managed according to dates.

---

## 9. Destination and Attraction Module

A destination will contain:

- Name
- District
- Description
- Latitude
- Longitude
- Images

A destination may contain multiple attractions and activities.

Attractions can contain:

- Name
- Description
- Location
- Entrance Fee
- Opening Hours
- Recommended Duration
- Images
- Availability

Activities may contain:

- Activity Name
- Description
- Price
- Duration
- Minimum Participants
- Maximum Participants
- Availability

---

## 10. Trip Cart

The Trip Cart is different from a normal shopping cart.

It represents services selected for one specific trip.

The Trip Cart may contain:

- Accommodation Rooms
- Restaurant Services
- Food Items
- Buffet Packages
- Attractions
- Activities

The system will calculate an estimated trip service cost.

Transport cost will be added after the traveler accepts a driver bid.

---

## 11. Driver Bidding System

After the traveler completes trip planning, a transport request is created.

The request can include:

- Pickup Location
- Starting Coordinates
- Destinations
- Destination Order
- Total Approximate Distance
- Estimated Driving Duration
- Trip Start Date
- Trip End Date
- Number of Passengers
- Luggage Requirements
- Special Requirements

Registered and eligible drivers can view the request.

A driver bid can contain:

- Driver
- Vehicle
- Bid Amount
- Message
- Bid Status
- Bid Creation Time
- Bid Expiration Time

Possible bid statuses:

- Pending
- Accepted
- Rejected
- Withdrawn
- Expired

Only the traveler who created the trip can select the winning bid.

---

## 12. Maps and Location Services

TripMate will use location-based services for:

- Traveler starting location
- Destination locations
- Restaurant locations
- Accommodation locations
- Attraction locations
- Driver route planning

The system should support:

- Latitude and Longitude
- Geolocation
- Multiple Destination Routing
- Distance Calculation
- Estimated Travel Duration
- Map Display
- Trip Progress Tracking

---

## 13. AI Trip Planner

The AI Trip Planner acts as an assistant and does not replace normal trip planning.

Inputs may include:

- Number of Travelers
- Number of Days
- Starting Location
- Budget
- Preferred Destinations
- Interests
- Accommodation Preferences
- Food Preferences

AI suggestions may include:

- Suitable Destinations
- Suggested Route
- Accommodation Options
- Restaurant Suggestions
- Activities
- Estimated Budget Distribution

AI suggestions must be confirmed by the traveler before being added to an actual trip.

---

## 14. Booking Management

Booking types may include:

- Accommodation Booking
- Restaurant Reservation
- Activity Booking
- Transport Booking

Possible booking statuses:

- Pending
- Confirmed
- Cancelled
- Completed

Booking records must keep historical information even if service information later changes.

---

## 15. Reviews and Ratings

After completing a service or trip, travelers may submit reviews.

Reviews may apply to:

- Restaurants
- Accommodation
- Drivers
- Attractions
- Activities

A review may contain:

- Rating
- Comment
- Review Date

Only eligible users should be allowed to review completed services.

---

## 16. Notifications

Notifications may include:

- New Driver Bid
- Bid Accepted
- Bid Rejected
- Booking Confirmed
- Booking Cancelled
- Upcoming Trip
- Restaurant Booking Update
- Accommodation Booking Update
- Driver Trip Reminder

---

## 17. Security

TripMate must use secure access control.

Important security requirements include:

- Supabase Authentication
- Role-Based Access Control
- Row Level Security
- Foreign Key Constraints
- Protected User Roles
- Secure Backend Environment Variables
- Protected API Keys
- Input Validation
- Authorization Checks

Sensitive credentials must never be committed to GitHub.

---

## 18. Technology Stack

### Frontend

React
Vite
HTML through JSX
CSS
JavaScript

### Backend

Python
FastAPI

### Database

Supabase
PostgreSQL

### Authentication

Supabase Auth

### Version Control

Git
GitHub

### Maps

A suitable mapping and route service will be integrated.

### AI

An AI service will be accessed through the backend.

---

## 19. System Architecture

React Frontend
↓
FastAPI Backend
↓
Supabase PostgreSQL Database

External Services:

- Maps / Routes
- Geolocation
- AI Service

Sensitive service credentials will remain in the backend environment configuration.

---

## 20. GitHub Development Structure

Main branch:

main

Feature branches:

feature/traveler
feature/restaurant
feature/accommodation
feature/driver
feature/maps-ai

The main branch will contain the stable integrated application.

Team members will develop features in their assigned branches and merge completed work through Pull Requests.

---

## 21. Current Database Progress

Completed:

- profiles
- destinations
- trips
- trip_destinations
- restaurants
- food_items
- buffet_packages

The restaurant-related tables will be refined before continuing with the remaining database implementation.

---

## 22. Development Strategy

The project will be developed in phases.

The database architecture will be designed before implementing dependent frontend and backend features.

Each major module will be reviewed for:

- Required Features
- Hidden Industry Requirements
- Database Relationships
- Security Requirements
- User Workflow
- API Requirements
- Integration Requirements
- Future Extensibility

This reduces unnecessary database redesign during later stages of development.

---

## 23. Viva Preparation Strategy

Every important part of the system must be understood by the development team.

For each implemented feature, the team should understand:

- Why the feature is required.
- Which files implement it.
- How data flows through the system.
- Which database tables are involved.
- Why specific database relationships are used.
- How security is implemented.
- How frontend and backend communicate.
- What happens when the feature fails.
- How the feature integrates with other modules.

The project should not contain unexplained code.

---

## 24. Final Goal

The final TripMate system should allow a traveler to:

Plan a Trip
↓
Select Destinations
↓
Find Accommodation
↓
Find Restaurants
↓
Select Attractions and Activities
↓
Build a Trip Cart
↓
Calculate Route and Distance
↓
Request Transport
↓
Receive Driver Bids
↓
Select a Driver
↓
Confirm Bookings
↓
Complete the Trip
↓
Submit Reviews

TripMate should operate as one integrated travel planning and service marketplace rather than a collection of separate systems.
