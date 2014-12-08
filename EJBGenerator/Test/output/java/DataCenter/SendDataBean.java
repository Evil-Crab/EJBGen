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
public class SendDataBean {

    @EJB
Requests3Bean Requests3;


    @Resource
    TimerService timerService;
    long duration = 50;

    Map<String, Boolean> inputs = new HashMap<String, Boolean>();
    String name = "SendData";
    boolean inWork = false;
    boolean waiting4Check = false;


    @PostConstruct
    void init() {
        inputs.put("Requests3", false);

    }

    public void reciveNotification(String name, Boolean status) {
        inputs.put(name, status);
        checkInputs();
    }

    @Timeout
    public void timeout() {
        waiting4Check = false;
        checkInputs();
    }

    private void checkInputs()
    {
        if(inWork)
        {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
            return;
        }

        inWork = true;
        boolean inputsFull = true;
        List<Boolean> list =  new ArrayList<Boolean>(inputs.values());
        for(int i = 0; i < inputs.size(); i++)
        {
            inputsFull = inputsFull && list.get(i);
        }

        if(inputsFull)
        {
            triggerTransition();
        }

        inWork = false;
    }

    private void triggerTransition() {
        if (blockInputs() && checkExtra()) {

          String token;
token = Requests3.getFirstToken();
Requests3.removeToken(token);
doExtraStuff();
unblockInputs();


        } else {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
        }
    }

    private boolean blockInputs() {
        boolean blocked = true;
        blocked = blocked && Requests3.blockPosition(name);

        if (!blocked) {
            unblockInputs();
        }

        return blocked;
    }

    private void unblockInputs()
    {
        Requests3.unblockPosition(name);

    }
    private boolean checkExtra() {
        return true;

    }

    private void doExtraStuff() {
        System.out.println("TRANSITION " + name + " EXECUTED");
    }

}
