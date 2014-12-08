package DataCenter;

import java.util.ArrayList;
import java.util.List;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;
import java.util.Timer;
import java.util.TimerTask;
import javax.ejb.Singleton;
import javax.ejb.Startup;


@Startup
@Singleton
public class IdleBean {


    @EJB
StartBean Start;


    List<String> list = new ArrayList<String>();
    String name = "Idle";

    @EJB
DroneManagerBean DroneManager;

    Timer timer = new Timer();

    String blocked = "";

    @PostConstruct
    void init() {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                addToken(DroneManager.createToken("291482"));
addToken(DroneManager.createToken("291482"));
addToken(DroneManager.createToken("291482"));
notifyTransitions();

            }
        }, 1000);

    }

    public void notifyTransitions() {
        if(!list.isEmpty())
        {
            Start.reciveNotification(name, true);

        } else
        {
            Start.reciveNotification(name, false);

        }
    }

    public Boolean blockPosition(String name) {
        if((blocked.equals("") || blocked.equals(name)) && (!list.isEmpty()))
        {
            blocked = name;
            return true;
        }

        return false;
    }

    public void unblockPosition(String name) {
        if(blocked.equals(name) || blocked.equals(""))
        {
            blocked = "";
            notifyTransitions();
        }
    }

    public String getFirstToken() {
        return list.get(0);
    }

    public List<String> getTokens() {
        return list;
    }

    public void removeToken(String id) {
        list.remove(list.indexOf(id));
    }

    public void addToken(String id) {
        list.add(id);
        if(blocked.equals(""))
            notifyTransitions();
    }

    

}
