package DataCenter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;



@Startup
@Singleton
public class GetTaskBean {


    @EJB
WaitingBean Waiting;
@EJB
StartingBean Starting;


    Map<String, Map<String, Boolean>> inputs = new HashMap<String, Map<String, Boolean>>();
    String name = "GetTask";
    Map<String, String> synch = new HashMap<String, String>();

    @PostConstruct
    void init() {
    }

    public void reciveNotification(String key, String name, Boolean status) {
        inputs.get(key).put(name, status);
        //checkInputs(key);
    }

    public boolean synchronize(String key, String name) {
        if (synch.get(key).equals("") || synch.get(key).equals(name)) {
            boolean inputsFull = true;
            List<Boolean> list =  new ArrayList<Boolean>(inputs.get(key).values());
            for (int i = 0; i < inputs.get(key).size(); i++) {
                inputsFull = inputsFull && list.get(i);
            }

            if (inputsFull && blockInputs(key) && checkExtra(key)) {
                synch.put(key, name);
                return true;
            } else {
                unblockInputs(key);
            }
            return false;
        } else
        {
            return false;
        }
    }

    public void removeSynchronization(String key, String name) {
        if(!key.equals("") && synch.get(key).equals(name))
        {
            synch.put(key, "");
            unblockInputs(key);
        }
    }


    public void triggerTransition(String key) {
        String token;
token = Waiting.getFirstToken(key);
Waiting.removeToken(key, token);
Starting.createToken(key);


        doExtraStuff(key);
        unblockInputs(key);
        synch.put(key, "");
    }


    private boolean blockInputs(String key) {
        boolean blocked = true;
        blocked = blocked && Waiting.blockPosition(key, name);

        if (!blocked) {
            unblockInputs(key);
        }

        return blocked;
    }

    private void unblockInputs(String key) {
        Waiting.unblockPosition(key, name);

    }

    private boolean checkExtra(String key) {
        return true;

    }

    private void doExtraStuff(String key) {
        
    }

    public void createNetToken(String key)
    {
        Map<String, Boolean> map = new HashMap<String, Boolean>();
        map.put("Waiting", false);

        inputs.put(key, map);
        synch.put(key, "");
    }

    public void destroyNetToken(String key)
    {
        inputs.remove(key);
        synch.remove(key);
    }
}
