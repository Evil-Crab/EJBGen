
package DataCenter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.annotation.PostConstruct;
import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.ejb.Timeout;
import javax.ejb.Timer;
import javax.ejb.TimerService;



@Startup
@Singleton
public class ReadDataBean {


    @EJB
SearchingBean Searching;
@EJB
ReadingBean Reading;


    @Resource
    TimerService timerService;
    long duration = 50;

    Map<String, Map<String, Boolean>> inputs = new HashMap<String, Map<String, Boolean>>();
    String name = "ReadData";

    boolean inWork = false;
    List<String> waiting4Check = new ArrayList<String>() ;


    @PostConstruct
    void init() {
    }

    public void reciveNotification(String key, String name, Boolean status) {
        inputs.get(key).put(name, status);
        checkInputs(key);
    }

    @Timeout
    public void timeout() {
        if (!waiting4Check.isEmpty()) {
            String waitingKey = waiting4Check.get(0);
            waiting4Check.remove(waitingKey);
            checkInputs(waitingKey);
        }
    }

    private void checkInputs(String key)
    {
        if(inWork)
        {
            if(!waiting4Check.contains(key))
            {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check.add(key);
            }
            return;
        }
        inWork = true;


        boolean inputsFull = true;
        List<Boolean> list = new ArrayList<Boolean>(inputs.get(key).values());
        for (int i = 0; i < inputs.get(key).size(); i++) {
            inputsFull = inputsFull && list.get(i);
        }

        if (inputsFull) {
            triggerTransition(key);
        } else {
            unblockInputs(key);
        }


        inWork = false;
            //checkInputs();
    }

    private void triggerTransition(final String key)
    {
        if(!blockInputs(key))
        {
            Timer timer = timerService.createTimer(duration, null);
            waiting4Check.add(key);
        } else if(checkExtra(key))
        {

            String token;
token = Searching.getFirstToken(key);
Searching.removeToken(key, token);
Reading.createToken(key);


            doExtraStuff(key);
            unblockInputs(key);

        }
    }

    private boolean blockInputs(String key) {
        boolean blocked = true;
        blocked = blocked && Searching.blockPosition(key, name);

        if (!blocked) {
            unblockInputs(key);
        }

        return blocked;
    }

    private void unblockInputs(String key) {
        Searching.unblockPosition(key, name);

    }

    private boolean checkExtra(String key) {
        return true;

    }

    private void doExtraStuff(String key) {
        System.out.println("SUBNET: " + key + "; TRANSITION " + name + " EXECUTED");
    }

    public void createNetToken(String key)
    {
        Map<String, Boolean> map = new HashMap<String, Boolean>();
        map.put("Searching", false);

        inputs.put(key, map);;
    }

    public void destroyNetToken(String key)
    {
        inputs.remove(key);
        waiting4Check.remove(key);
    }
}
