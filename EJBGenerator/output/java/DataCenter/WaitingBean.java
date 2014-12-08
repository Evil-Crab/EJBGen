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
public class WaitingBean {

    @EJB
GetTaskBean GetTask;


    List<String> keys = new ArrayList<String>();
    Map<String, List<String>> list = new HashMap<String, List<String>>();
    String type = "black";
    String name = "Waiting";
    Integer idCounter = 0;

    Map<String, String> blocked = new HashMap<String, String>();

    @PostConstruct
    void init() {

    }

    public void notifyTransitions() {
        List<String> tmpList;
        for (int i = 0; i < keys.size(); i++) {
            tmpList = list.get(keys.get(i));
            if (!tmpList.isEmpty()) {
                GetTask.reciveNotification(keys.get(i), name, true);


            } else {
                GetTask.reciveNotification(keys.get(i), name, false);

            }
        }
    }

    public Boolean blockPosition(String key, String name) {
        if((blocked.get(key).equals("") || blocked.get(key).equals(name)) && (!list.get(key).isEmpty()))
        {
            blocked.put(key, name);
            return true;
        }

        return false;
    }

    public void unblockPosition(String key, String name) {
        if(blocked.get(key).equals(name))
        {
            blocked.put(key, "");
            notifyTransitions();
        }
    }

    public String getFirstToken(String key) {
        return list.get(key).get(0);
    }

    public List<String> getTokens(String key) {
        return list.get(key);
    }

    public void removeToken(String key, String id) {
        list.get(key).remove(list.get(key).indexOf(id));
    }

    public void addToken(String key, String id) {
        list.get(key).add(id);
        if(blocked.get(key).equals(""))
            notifyTransitions();
    }

    public void createToken(String key) {
        idCounter++;
        list.get(key).add(type + "_" + name + "_" + idCounter);
        notifyTransitions();
    }

    public void createNetToken(String key)
    {
        keys.add(key);
        list.put(key, new ArrayList<String>());
        blocked.put(key, "");
    }

    public void destroyNetToken(String key)
    {
        keys.remove(key);
        list.remove(key);
        blocked.remove(key);
    }
}
