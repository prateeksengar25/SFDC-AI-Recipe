/**
 * @description Domain class representing an Activity record
 * Implements the Domain layer of the Enterprise Design Pattern
 * Handles business logic and data transformation for activities
 */
public class Activity {
    public String type;
    public String subject;
    public String description;
    public String status;
    public Datetime activityDate;
    public String relatedTo;
    
    /**
     * @description Constructor for creating an Activity instance
     * @param type The type of activity (Task, Event, or Email)
     * @param subject The subject of the activity
     * @param description The description or body of the activity
     * @param status The status of the activity
     * @param activityDate The date/time of the activity
     * @param relatedTo The name of the related record
     */
    public Activity(String type, String subject, String description, String status, Datetime activityDate, String relatedTo) {
        this.type = type;
        this.subject = subject;
        this.description = description;
        this.status = status;
        this.activityDate = activityDate;
        this.relatedTo = relatedTo;
    }
    
    /**
     * @description Creates Activity instances from a list of Task records
     * @param tasks List of Task records to convert
     * @return List of Activity instances
     */
    public static List<Activity> createFromTasks(List<Task> tasks) {
        List<Activity> activities = new List<Activity>();
        for (Task t : tasks) {
            activities.add(new Activity(
                'Task',
                t.Subject,
                t.Description,
                t.Status,
                t.CreatedDate,
                t.What.Name
            ));
        }
        return activities;
    }
    
    /**
     * @description Creates Activity instances from a list of Event records
     * @param events List of Event records to convert
     * @return List of Activity instances
     */
    public static List<Activity> createFromEvents(List<Event> events) {
        List<Activity> activities = new List<Activity>();
        for (Event e : events) {
            activities.add(new Activity(
                'Event',
                e.Subject,
                e.Description,
                'Completed',
                e.ActivityDateTime,
                e.What.Name
            ));
        }
        return activities;
    }
    
    /**
     * @description Creates Activity instances from a list of EmailMessage records
     * @param emails List of EmailMessage records to convert
     * @return List of Activity instances
     */
    public static List<Activity> createFromEmails(List<EmailMessage> emails) {
        List<Activity> activities = new List<Activity>();
        for (EmailMessage em : emails) {
            activities.add(new Activity(
                'Email',
                em.Subject,
                em.TextBody,
                'Sent',
                em.CreatedDate,
                em.RelatedTo.Name
            ));
        }
        return activities;
    }
    
    /**
     * @description Sorts a list of activities by date in descending order
     * @param activities List of activities to sort
     * @return Sorted list of activities
     */
    public static List<Activity> sortByDate(List<Activity> activities) {
        if (activities != null && !activities.isEmpty()) {
            activities.sort(new ActivityDateComparator());
        }
        return activities;
    }
    
    /**
     * @description Comparator class for sorting activities by date
     */
    private class ActivityDateComparator implements Comparator<Activity> {
        /**
         * @description Compares two activities based on their dates
         * @param a1 First activity to compare
         * @param a2 Second activity to compare
         * @return -1 if a1 is more recent, 1 if a2 is more recent, 0 if equal
         */
        public Integer compare(Activity a1, Activity a2) {
            if (a1.activityDate > a2.activityDate) return -1;
            if (a1.activityDate < a2.activityDate) return 1;
            return 0;
        }
    }
} 